// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IIrm} from "../interfaces/IIrm.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IPegToken} from "../interfaces/IPegToken.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {Position} from "./Position.sol";
import {BorrowShare} from "./BorrowShare.sol";
import {FungibleAssetParams} from "./FungibleAssetParams.sol";
import {NonFungibleAssetId} from "./NonFungibleAssetId.sol";
import {Math} from "../libraries/Math.sol";
import {SafeCast} from "../libraries/SafeCast.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

struct Pool {
    IIrm irm;
    IOracle oracle;
    address owner;
    uint8 reservesCount;
    uint8 feeRatio;
    uint8 ownerFeeRatio;
    uint64 lastUpdate;
    int128 ownerFee;
    int128 riskReverseFee;
    uint256 totalBorrowAssets;
    BorrowShare totalBorrowShares;
    uint256 cacheDonateBalance;
    mapping(uint256 fungibleAssetId => FungibleAssetParams) fungibleAssetParams;
    mapping(address nft => bool isCollateral) isNFTCollateral;
    mapping(address nft => uint256 lltv) nonFungibleAssetParams;
    mapping(uint256 id => Position) positions;
}

using PoolLibrary for Pool global;

library PoolLibrary {
    using SafeCast for uint256;
    using SafeCast for int256;

    error PoolAlreadyInitialized();
    error PoolNotInitialized();
    error InvaildFungibleAsset();
    error InvaildNonFungibleAsset();

    error PositionIsHealthy();
    error PositionIsNotHealthy();
    error OnlyOwner();

    uint256 constant MIN_LIQUIDATION_INCENTIVE_FACTOR = 0.99e18;
    address constant UNISWAP_V4 = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
    uint160 constant INIT_PRICE = 0x1000000000000000000000000;

    function initialize(
        Pool storage self,
        PoolKey memory poolKey,
        address owner,
        IIrm irm,
        IOracle oracle,
        uint8 feeRatio,
        uint8 ownerFeeRatio
    ) external {
        require(self.reservesCount == 0, PoolAlreadyInitialized());
        IPoolManager(UNISWAP_V4).initialize(poolKey, INIT_PRICE);

        self.irm = irm;
        self.oracle = oracle;
        self.owner = owner;
        self.feeRatio = feeRatio;
        self.ownerFeeRatio = ownerFeeRatio;

        // underlyingToken
        self.fungibleAssetParams[0] = FungibleAssetParams({asset: poolKey.currency1, lltv: 1e6});
        // pegToken
        self.fungibleAssetParams[1] = FungibleAssetParams({asset: poolKey.currency0, lltv: 0.99e6});

        self.reservesCount = 2;
    }

    function checkPoolInitialized(Pool storage self) external view {
        require(self.reservesCount > 0, PoolNotInitialized());
    }

    function onlyOwner(Pool storage self) external view {
        require(msg.sender == self.owner, OnlyOwner());
    }

    function setOwner(Pool storage self, address newOwner) external {
        self.owner = newOwner;
    }

    function enableFungibleCollateral(Pool storage self, Currency reserve, uint96 lltv)
        external
        returns (uint256 assetId)
    {
        assetId = self.reservesCount;
        self.fungibleAssetParams[assetId] = FungibleAssetParams({asset: reserve, lltv: lltv});

        self.reservesCount += 1;
    }

    function updateFungibleCollateral(Pool storage self, uint256 fungibleAssetId, uint96 lltv)
        external
        returns (Currency fungibleAddress)
    {
        fungibleAddress = self.fungibleAssetParams[fungibleAssetId].asset;
        self.fungibleAssetParams[fungibleAssetId].lltv = lltv;
    }

    function updateNonFungibleCollateral(Pool storage self, address reserve, uint256 lltv) external {
        self.nonFungibleAssetParams[reserve] = lltv;
        self.isNFTCollateral[reserve] = true;
    }

    function updateFeeRatio(Pool storage self, uint8 feeRatio, uint8 ownerFeeRatio) external {
        self.feeRatio = feeRatio;
        self.ownerFeeRatio = ownerFeeRatio;
    }

    /* SUPPLY MANAGEMENT */

    // TODO: pool id in position id
    function supplyFungibleCollateral(
        Pool storage self,
        PoolKey memory poolKey,
        uint256 positionId,
        uint256 fungibleAssetId,
        uint256 amount
    ) external returns (Currency fungibleToken) {
        fungibleToken = self.fungibleAssetParams[fungibleAssetId].asset;

        require(self.fungibleAssetParams[fungibleAssetId].lltv != 0, InvaildFungibleAsset());

        Position storage position = self.positions[positionId];

        accrueInterest(self, poolKey, false);

        position.addFungible(fungibleAssetId, amount);
    }

    function supplyNonFungibleCollateral(
        Pool storage self,
        PoolKey memory poolKey,
        uint256 positionId,
        NonFungibleAssetId nonFungibleAssetId
    ) external {
        Position storage position = self.positions[positionId];
        address nftAddress = nonFungibleAssetId.nft();
        uint256 tokenId = nonFungibleAssetId.tokenId();

        require(self.isNFTCollateral[nftAddress], InvaildNonFungibleAsset());

        accrueInterest(self, poolKey, false);

        position.addNonFungible(nonFungibleAssetId);

        IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);
    }

    /* BORROW MANAGEMENT */

    function borrow(Pool storage self, PoolKey memory poolKey, uint256 positionId, BorrowShare share)
        external
        returns (uint256 borrowAsset)
    {
        Position storage position = self.positions[positionId];
        position.checkSenderAuthorized();
        position.borrow(share);

        accrueInterest(self, poolKey, false);

        borrowAsset = share.toAssetsDown(self.totalBorrowAssets, self.totalBorrowShares);

        self.totalBorrowAssets += borrowAsset;
        self.totalBorrowShares = self.totalBorrowShares + share;
    }

    function repay(Pool storage self, PoolKey memory poolKey, uint256 positionId, BorrowShare share)
        external
        returns (uint256 repayAsset)
    {
        Position storage position = self.positions[positionId];
        position.repay(share);

        accrueInterest(self, poolKey, false);

        repayAsset = share.toAssetsUp(self.totalBorrowAssets, self.totalBorrowShares);

        self.totalBorrowAssets -= repayAsset;
        self.totalBorrowShares = self.totalBorrowShares - share;
    }

    /* WITHDRAW MANAGEMENT */

    function withdrawFungibleCollateral(
        Pool storage self,
        PoolKey memory poolKey,
        uint256 positionId,
        uint256 fungibleAssetId,
        uint256 amount
    ) external returns (Currency fungible) {
        fungible = self.fungibleAssetParams[fungibleAssetId].asset;
        if (fungible == Currency.wrap(address(0))) {
            revert InvaildFungibleAsset();
        }

        Position storage position = self.positions[positionId];
        position.checkSenderAuthorized();

        accrueInterest(self, poolKey, false);

        position.removeFungible(fungibleAssetId, amount);
    }

    function withdrawNonFungibleCollateral(
        Pool storage self,
        PoolKey memory poolKey,
        uint256 positionId,
        NonFungibleAssetId nonFungibleAssetId
    ) external {
        Position storage position = self.positions[positionId];
        position.checkSenderAuthorized();

        address nftAddress = nonFungibleAssetId.nft();
        uint256 tokenId = nonFungibleAssetId.tokenId();

        accrueInterest(self, poolKey, false);

        position.removeNonFungible(nonFungibleAssetId);
        IERC721(nftAddress).transferFrom(address(this), msg.sender, tokenId);
    }

    /* LIQUIDATION */

    function liquidate(Pool storage self, PoolKey memory poolKey, uint256 positionId)
        external
        returns (uint256 repaidAsset, int256 bedDebtAsset)
    {
        Position storage position = self.positions[positionId];

        accrueInterest(self, poolKey, false);

        // maxBorrow = collateral value, borrowed = borrow peg token value
        (bool health, uint256 maxBorrow, uint256 borrowed) = position.isHealthy(
            self.fungibleAssetParams,
            self.nonFungibleAssetParams,
            self.oracle,
            self.reservesCount,
            self.totalBorrowAssets,
            self.totalBorrowShares
        );

        require(!health, PositionIsHealthy());

        (uint256 maxBorrowedAdjust, uint256 borrowedAdjust) = position.adjust(maxBorrow, borrowed);

        if (borrowedAdjust != 0) {
            uint256 liquidationIncentiveFactor = Math.mulDivDown(borrowedAdjust, 1e18, maxBorrowedAdjust);

            if (liquidationIncentiveFactor >= MIN_LIQUIDATION_INCENTIVE_FACTOR) {
                repaidAsset = borrowed;
            } else {
                repaidAsset = Math.mulDivDown(maxBorrow, MIN_LIQUIDATION_INCENTIVE_FACTOR, 1e18);

                bedDebtAsset = int256(borrowed) - int256(repaidAsset);

                if (bedDebtAsset < 0) {
                    self.riskReverseFee += bedDebtAsset.toInt128();
                }
            }
        }

        position.owner = msg.sender;
        position.authorizedOperator = address(0);
        position.borrowShares = BorrowShare.wrap(0);
    }

    /* INTEREST MANAGEMENT */

    // TODO: if manager unlock, save interest. if manager is not unlock, donate interest
    function accrueInterest(Pool storage self, PoolKey memory poolKey, bool isHook) public {
        uint256 elapsed = block.timestamp - self.lastUpdate;
        if (elapsed == 0) return;

        uint256 interest = self.irm.borrowRate(poolKey).compound(self.totalBorrowAssets, elapsed);

        self.totalBorrowAssets += interest;

        // TODO: Protocol fee
        uint256 allFee = interest * self.feeRatio / 100;
        uint256 ownerFee = allFee * self.ownerFeeRatio / 100;
        uint256 riskReverse = allFee - ownerFee;

        if (self.riskReverseFee >= 0) {
            self.ownerFee += ownerFee.toInt128();
            self.riskReverseFee += riskReverse.toInt128();
        } else {
            self.riskReverseFee += allFee.toInt128();
        }

        uint256 donateBalance = interest - allFee;

        if (isHook) {
            donateBalance += self.cacheDonateBalance;
            IPoolManager(UNISWAP_V4).donate(poolKey, 0, donateBalance, "");
            IPoolManager(UNISWAP_V4).sync(poolKey.currency0);
            IPegToken(Currency.unwrap(poolKey.currency0)).mint(UNISWAP_V4, donateBalance);
            IPoolManager(UNISWAP_V4).settle();

            self.cacheDonateBalance = 0;
        } else {
            self.cacheDonateBalance += donateBalance;
        }

        self.lastUpdate = uint64(block.timestamp);
    }

    /* HELPER FUNCTIONS */

    function isHealthy(Pool storage self, uint256 positionId) external view {
        Position storage position = self.positions[positionId];

        // maxBorrow = collateral value, borrowed = borrow peg token value
        (bool health,,) = position.isHealthy(
            self.fungibleAssetParams,
            self.nonFungibleAssetParams,
            self.oracle,
            self.reservesCount,
            self.totalBorrowAssets,
            self.totalBorrowShares
        );

        require(health, PositionIsNotHealthy());
    }

    function updatePositionAuthorization(
        Pool storage self,
        uint256 positionId,
        address owner,
        address authorizedOperator
    ) external {
        Position storage position = self.positions[positionId];
        if (position.owner != address(0)) {
            position.checkSenderAuthorized();
        }
        position.owner = owner;
        position.authorizedOperator = authorizedOperator;
    }
}
