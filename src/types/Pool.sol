// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IIrm} from "../interfaces/IIrm.sol";
import {IPegToken} from "../interfaces/IPegToken.sol";
import {Position} from "./Position.sol";
import {BorrowShare} from "./BorrowShare.sol";
import {FungibleAssetParams} from "./FungibleAssetParams.sol";
import {NonFungibleAssetId} from "./NonFungibleAssetId.sol";
import {SafeTransferLibrary} from "../libraries/SafeTransfer.sol";
import {SafeCast} from "../libraries/SafeCast.sol";
import {PegToken} from "../tokenization/PegToken.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

struct Pool {
    address pegToken;
    IIrm irm;
    address owner;
    uint8 reservesCount;
    uint8 feeRatio;
    uint8 ownerFeeRatio;
    uint64 lastUpdate;
    int128 ownerFee;
    int128 riskReverseFee;
    uint256 totalBorrowAssets;
    BorrowShare totalBorrowShares;
    PoolKey poolKey;
    mapping(uint256 fungibleAssetId => FungibleAssetParams) fungibleAssetParams;
    mapping(address nft => bool isCollateral) isNFTCollateral;
    mapping(address nft => uint256 lltv) nonFungibleAssetParams;
    mapping(uint256 id => Position) positions;
}

using PoolLibrary for Pool global;

library PoolLibrary {
    using SafeTransferLibrary for address;
    using SafeCast for uint256;

    error InvaildFungibleAsset();
    error InvaildNonFungibleAsset();
    error InvaildFeeRatio();
    error InvaildPegTokenSalt();

    address constant UNISWAP_V4 = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    uint160 constant INIT_PRICE = 0x1000000000000000000000000;

    function initialize(
        Pool storage self,
        address owner,
        address underlying,
        IIrm irm,
        uint8 feeRatio,
        uint8 ownerFeeRatio,
        bytes32 salt
    ) internal {
        // TODO: create2 pet token and set hook as owner
        // Depoly pegToken as token 0
        require(ownerFeeRatio < 100, InvaildFeeRatio());
        require(feeRatio < 100, InvaildFeeRatio());

        address pegToken = address(new PegToken{salt: salt}(underlying, address(this)));
        require(underlying < pegToken, InvaildPegTokenSalt());

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(pegToken),
            currency1: Currency.wrap(underlying),
            fee: 100, // 0.01%
            tickSpacing: 1,
            hooks: IHooks(address(this))
        });

        IPoolManager(UNISWAP_V4).initialize(poolKey, INIT_PRICE);

        self.pegToken = pegToken;
        self.irm = irm;
        self.owner = owner;
        self.feeRatio = feeRatio;
        self.ownerFeeRatio = ownerFeeRatio;
        self.poolKey = poolKey;
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
    function supplyFungibleCollateral(Pool storage self, uint256 positionId, uint256 fungibleAssetId, uint256 amount)
        external
    {
        address fungibleAddress = self.fungibleAssetParams[fungibleAssetId].asset;
        require(fungibleAddress != address(0), InvaildFungibleAsset());

        Position storage position = self.positions[positionId];

        accrueInterest(self);

        position.addFungible(fungibleAssetId, amount);

        fungibleAddress.safeTransferFrom(msg.sender, address(this), amount);
    }

    function supplyNonFungibleCollateral(Pool storage self, uint256 positionId, NonFungibleAssetId nonFungibleAssetId)
        external
    {
        Position storage position = self.positions[positionId];
        address nftAddress = nonFungibleAssetId.nft();
        uint256 tokenId = nonFungibleAssetId.tokenId();

        require(self.isNFTCollateral[nftAddress], InvaildNonFungibleAsset());

        accrueInterest(self);

        position.addNonFungible(nonFungibleAssetId);

        nftAddress.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    /* BORROW MANAGEMENT */

    function borrow(Pool storage self, address receiver, uint256 positionId, BorrowShare share) external {
        Position storage position = self.positions[positionId];
        position.borrow(share);

        uint256 borrowAsset = share.toAssetsDown(self.totalBorrowAssets, self.totalBorrowShares);
        IPegToken(self.pegToken).mint(receiver, borrowAsset);
    }

    function repay(Pool storage self, uint256 positionId, BorrowShare share) external {
        Position storage position = self.positions[positionId];
        position.repay(share);

        uint256 repayAsset = share.toAssetsUp(self.totalBorrowAssets, self.totalBorrowShares);
        IPegToken(self.pegToken).burn(msg.sender, repayAsset);
    }

    /* WITHDRAW MANAGEMENT */

    function withdrawFungibleCollateral(Pool storage self, uint256 positionId, uint256 fungibleAssetId, uint256 amount)
        internal
    {
        address fungibleAddress = self.fungibleAssetParams[fungibleAssetId].asset;
        require(fungibleAddress != address(0), InvaildFungibleAsset());

        Position storage position = self.positions[positionId];

        accrueInterest(self);

        position.removeFungible(fungibleAssetId, amount);

        fungibleAddress.safeTransfer(msg.sender, amount);
    }

    function withdrawNonFungibleCollateral(Pool storage self, uint256 positionId, NonFungibleAssetId nonFungibleAssetId)
        internal
    {
        Position storage position = self.positions[positionId];
        address nftAddress = nonFungibleAssetId.nft();
        uint256 tokenId = nonFungibleAssetId.tokenId();

        accrueInterest(self);

        position.removeNonFungible(nonFungibleAssetId);
        nftAddress.safeTransfer(msg.sender, tokenId);
    }

    /* LIQUIDATION */

    function liquidate(Pool storage self, uint256 positionId) external {}

    /* INTEREST MANAGEMENT */

    function accrueInterest(Pool storage self) internal {
        uint256 elapsed = block.timestamp - self.lastUpdate;
        if (elapsed == 0) return;

        uint256 interest = self.irm.borrowRate(self.poolKey).compound(self.totalBorrowAssets, elapsed);

        self.totalBorrowAssets += interest;

        // TODO: Protocol fee
        uint256 allFee = interest * self.feeRatio / 100;
        uint256 ownerFee = allFee * self.ownerFeeRatio / 100;
        uint256 riskReverse = allFee - ownerFee;

        self.ownerFee += ownerFee.toInt128();
        self.riskReverseFee += riskReverse.toInt128();

        uint256 donateBalance = interest - allFee;

        IPoolManager(UNISWAP_V4).donate(self.poolKey, 0, donateBalance, "");
        IPoolManager(UNISWAP_V4).sync(Currency.wrap(self.pegToken));
        IPegToken(self.pegToken).mint(UNISWAP_V4, donateBalance);
        IPoolManager(UNISWAP_V4).settle();

        self.lastUpdate = uint64(block.timestamp);
    }
}
