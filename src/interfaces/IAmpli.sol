// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {PositionId} from "../types/PositionId.sol";
import {NonFungibleAssetId} from "../types/NonFungibleAssetId.sol";

interface IAmpli {
    error InvaildOwner();
    error NotOwner();
    error InvaildFungibleAsset();
    error InvaildNonFungibleAsset();

    event SetOwner(address indexed newOwner);
    event SetAssetParams(uint256 indexed id, address indexed asset, address oracle, uint96 lltv);
    event SupplyFungibleCollateral(
        PositionId indexed id, address indexed caller, address indexed asset, uint256 amount
    );
    event SuppluNonFungibleCollateral(
        PositionId indexed id, address indexed caller, address indexed asset, uint256 tokenId
    );

    struct AssetParams {
        address oracle;
        uint96 lltv;
    }

    function setOwner(address newOwner) external;

    function enableFungibleCollateral(address asset, AssetParams calldata params) external;

    function enableNonFungibleCollateral(address asset) external;
}
