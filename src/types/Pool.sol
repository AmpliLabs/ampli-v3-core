// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {PositionId} from "./PositionId.sol";
import {Position} from "./Position.sol";
import {FungibleAssetParams} from "./FungibleAssetParams.sol";
import {NonFungibleAssetId} from "./NonFungibleAssetId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SafeTransferLibrary} from "../libraries/SafeTransfer.sol";

struct Pool {
    uint8 reservesCount;
    address owner;
    address petToken;
    mapping(uint256 fungibleAssetId => FungibleAssetParams) fungibleAssetParams;
    mapping(address nft => bool isCollateral) isNFTCollateral;
    mapping(address nft => uint256 lltv) nonFungibleAssetParams;
    mapping(PositionId => Position) positions;
}

using PoolLibrary for Pool global;

library PoolLibrary {
    using SafeTransferLibrary for address;

    error InvaildFungibleAsset();
    error InvaildNonFungibleAsset();

    function initialize(Pool storage self, address owner, bytes32 salt) internal {
        // TODO: create2 pet token and set hook as owner
    }

    function setOwner(Pool storage self, address newOwner) external {
        self.owner = newOwner;
    }

    function enableFungibleCollateral(Pool storage self, address reserve, uint96 lltv) external {
        self.fungibleAssetParams[self.reservesCount] = FungibleAssetParams({
            asset: reserve,
            lltv: lltv
        });

        self.reservesCount += 1;
    }

    function enableNonFungibleCollateral(Pool storage self, address reserve, uint256 lltv) external {
        self.nonFungibleAssetParams[reserve] = lltv;
        self.isNFTCollateral[reserve] = true;
    }

    /* SUPPLY MANAGEMENT */

    // TODO: pool id in position id
    function supplyFungibleCollateral(Pool storage self, PositionId positionId, uint256 fungibleAssetId, uint256 amount) external {
        address fungibleAddress = self.fungibleAssetParams[fungibleAssetId].asset;
        require(fungibleAddress != address(0), InvaildFungibleAsset());

        Position storage position = self.positions[positionId];

        // TODO: accrue interest

        position.addFungible(fungibleAssetId, amount);

        fungibleAddress.safeTransferFrom(msg.sender, address(this), amount);

        // TODO: checkout position
    }

    function supplyNonFungibleCollateral(Pool storage self, PositionId positionId, NonFungibleAssetId nonFungibleAssetId) external {
        Position storage position = self.positions[positionId];
        address nftAddress = nonFungibleAssetId.nft();
        uint256 tokenId = nonFungibleAssetId.tokenId();

        require(self.isNFTCollateral[nftAddress], InvaildNonFungibleAsset());

        // TODO: accrue interest

        position.addNonFungible(nonFungibleAssetId);

        nftAddress.safeTransferFrom(msg.sender, address(this), tokenId);

        // TODO: checkout position
    }
}
