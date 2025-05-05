// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IIrm} from "../interfaces/IIrm.sol";
import {Position} from "./Position.sol";
import {FungibleAssetParams} from "./FungibleAssetParams.sol";
import {NonFungibleAssetId} from "./NonFungibleAssetId.sol";
import {SafeTransferLibrary} from "../libraries/SafeTransfer.sol";
import {SafeCast} from "../libraries/SafeCast.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

struct Pool {
    address pedToken;
    IIrm irm;
    address owner;
    uint8 reservesCount;
    uint8 feeRatio;
    uint8 ownerFeeRatio;
    uint64 lastUpdate;
    int128 ownerFee;
    int128 riskReverseFee;
    uint256 totalBorrowAssets;
    uint256 totalBorrowShares;
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
    error InvaildOwnerFeeReserve();

    address constant UNISWAP_V4 = 0x000000000004444c5dc75cB358380D2e3dE08A90;

    function initialize(Pool storage self, address owner, bytes32 salt, uint8 ownerFeeRatio) internal {
        // TODO: create2 pet token and set hook as owner
        // Depoly Token as token 1

        require(ownerFeeRatio < 100, InvaildOwnerFeeReserve());
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

        // TODO: checkout position
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

        // TODO: checkout position
    }

    function accrueInterest(Pool storage self) internal {
        uint256 elapsed = block.timestamp - self.lastUpdate;
        if (elapsed == 0) return;

        uint256 interest = self.irm.borrowRate(self.poolKey).compound(self.totalBorrowAssets, elapsed);

        self.totalBorrowAssets += interest;

        int128 allFee = (interest * self.feeRatio / 100).toInt128();
        int128 ownerFee = (allFee * self.ownerFeeRatio / 100).toInt128();
        int128 riskReverse = allFee - ownerFee;

        self.ownerFee += ownerFee;
        self.riskReverseFee += riskReverse;

        IPoolManager(UNISWAP_V4).donate(self.poolKey, 0, interest - uint256(int128(allFee)), "");

        // TODO: mint and settle
        self.lastUpdate = uint64(block.timestamp);
    }
}
