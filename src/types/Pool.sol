// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IIrm} from "../interfaces/IIrm.sol";
import {IPegToken} from "../interfaces/IPegToken.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {Position} from "./Position.sol";
import {BorrowShare} from "./BorrowShare.sol";
import {FungibleAssetParams} from "./FungibleAssetParams.sol";
import {NonFungibleAssetId} from "./NonFungibleAssetId.sol";
import {SafeTransferLibrary} from "../libraries/SafeTransfer.sol";
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
    mapping(uint256 fungibleAssetId => FungibleAssetParams) fungibleAssetParams;
    mapping(address nft => bool isCollateral) isNFTCollateral;
    mapping(address nft => uint256 lltv) nonFungibleAssetParams;
    mapping(uint256 id => Position) positions;
}

using PoolLibrary for Pool global;

library PoolLibrary {
    using SafeTransferLibrary for address;
    using SafeCast for uint256;
    using SafeCast for int256;

    error InvaildFungibleAsset();
    error InvaildNonFungibleAsset();

    error PositionIsHealthy();
    error PositionIsNotHealthy();

    uint256 constant MIN_LIQUIDATION_INCENTIVE_FACTOR = 0.99e18;
    address constant UNISWAP_V4 = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    uint160 constant INIT_PRICE = 0x1000000000000000000000000;

    function initialize(
        Pool storage self,
        PoolKey memory poolKey,
        address owner,
        IIrm irm,
        IOracle oracle,
        uint8 feeRatio,
        uint8 ownerFeeRatio
    ) internal {
        IPoolManager(UNISWAP_V4).initialize(poolKey, INIT_PRICE);

        self.irm = irm;
        self.oracle = oracle;
        self.owner = owner;
        self.feeRatio = feeRatio;
        self.ownerFeeRatio = ownerFeeRatio;

        self.fungibleAssetParams[0] = FungibleAssetParams({asset: Currency.unwrap(poolKey.currency1), lltv: 1e6});
        self.fungibleAssetParams[1] = FungibleAssetParams({asset: Currency.unwrap(poolKey.currency0), lltv: 0.99e6});

        self.reservesCount = 2;
    }

    function setOwner(Pool storage self, address newOwner) external {
        self.owner = newOwner;
    }

    function enableFungibleCollateral(Pool storage self, address reserve, uint96 lltv) external {
        self.fungibleAssetParams[self.reservesCount] = FungibleAssetParams({asset: reserve, lltv: lltv});

        self.reservesCount += 1;
    }

    function enableNonFungibleCollateral(Pool storage self, address reserve, uint256 lltv) external {
        self.nonFungibleAssetParams[reserve] = lltv;
        self.isNFTCollateral[reserve] = true;
    }

    /* SUPPLY MANAGEMENT */

    // TODO: pool id in position id
    function supplyFungibleCollateral(
        Pool storage self,
        PoolKey memory poolKey,
        uint256 positionId,
        uint256 fungibleAssetId,
        uint256 amount
    ) external returns (address fungibleAddress) {
        fungibleAddress = self.fungibleAssetParams[fungibleAssetId].asset;
        require(self.fungibleAssetParams[fungibleAssetId].lltv != 0, InvaildFungibleAsset());

        Position storage position = self.positions[positionId];

        accrueInterest(self, poolKey);

        position.addFungible(fungibleAssetId, amount);

        fungibleAddress.safeTransferFrom(msg.sender, address(this), amount);
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

        accrueInterest(self, poolKey);

        position.addNonFungible(nonFungibleAssetId);

        nftAddress.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    /* BORROW MANAGEMENT */

    function borrow(Pool storage self, PoolKey memory poolKey, address receiver, uint256 positionId, BorrowShare share)
        external
        returns (uint256 borrowAsset)
    {
        Position storage position = self.positions[positionId];
        position.borrow(share);

        borrowAsset = share.toAssetsDown(self.totalBorrowAssets, self.totalBorrowShares);
        IPegToken(Currency.unwrap(poolKey.currency0)).mint(receiver, borrowAsset);
    }

    function repay(Pool storage self, PoolKey memory poolKey, uint256 positionId, BorrowShare share)
        external
        returns (uint256 repayAsset)
    {
        Position storage position = self.positions[positionId];
        position.repay(share);

        repayAsset = share.toAssetsUp(self.totalBorrowAssets, self.totalBorrowShares);
        IPegToken(Currency.unwrap(poolKey.currency0)).burn(msg.sender, repayAsset);
    }

    /* WITHDRAW MANAGEMENT */

    function withdrawFungibleCollateral(
        Pool storage self,
        PoolKey memory poolKey,
        uint256 positionId,
        uint256 fungibleAssetId,
        uint256 amount
    ) internal returns (address fungibleAddress) {
        fungibleAddress = self.fungibleAssetParams[fungibleAssetId].asset;
        require(fungibleAddress != address(0), InvaildFungibleAsset());

        Position storage position = self.positions[positionId];

        accrueInterest(self, poolKey);

        position.removeFungible(fungibleAssetId, amount);

        fungibleAddress.safeTransfer(msg.sender, amount);
    }

    function withdrawNonFungibleCollateral(
        Pool storage self,
        PoolKey memory poolKey,
        uint256 positionId,
        NonFungibleAssetId nonFungibleAssetId
    ) internal {
        Position storage position = self.positions[positionId];
        address nftAddress = nonFungibleAssetId.nft();
        uint256 tokenId = nonFungibleAssetId.tokenId();

        accrueInterest(self, poolKey);

        position.removeNonFungible(nonFungibleAssetId);
        nftAddress.safeTransfer(msg.sender, tokenId);
    }

    /* LIQUIDATION */

    function liquidate(Pool storage self, PoolKey memory poolKey, uint256 positionId)
        external
        returns (uint256 repaidAsset, int256 bedDebtAsset)
    {
        Position storage position = self.positions[positionId];

        accrueInterest(self, poolKey);

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

            IPegToken(Currency.unwrap(poolKey.currency0)).burn(msg.sender, repaidAsset);
        }

        position.owner = msg.sender;
        position.borrowShares = BorrowShare.wrap(0);
    }

    /* INTEREST MANAGEMENT */

    function accrueInterest(Pool storage self, PoolKey memory poolKey) internal {
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

        IPoolManager(UNISWAP_V4).donate(poolKey, 0, donateBalance, "");
        IPoolManager(UNISWAP_V4).sync(poolKey.currency0);
        IPegToken(Currency.unwrap(poolKey.currency0)).mint(UNISWAP_V4, donateBalance);
        IPoolManager(UNISWAP_V4).settle();

        self.lastUpdate = uint64(block.timestamp);
    }

    /* HELPER FUNCTIONS */

    function isHealthy(Pool storage self, uint256 positionId) internal view {
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
}
