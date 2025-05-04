// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {NonFungibleAssetId} from "../types/NonFungibleAssetId.sol";

interface IAmpli {
    error InvaildOwner();
    error NotOwner();

    event SetOwner(address indexed newOwner);
    event SetFungibleCollateral(uint256 indexed id, address indexed asset, uint256 lltv);
    event SetNonFungibleCollateral(address indexed asset, uint256 lltv);

    event SupplyFungibleCollateral(
        uint256 indexed id, address indexed caller, address indexed asset, uint256 amount
    );
    event SuppluNonFungibleCollateral(
        uint256 indexed id, address indexed caller, address indexed asset, uint256 tokenId
    );

    function setOwner(address newOwner) external;

    function enableFungibleCollateral(address asset, uint256 lltv) external;

    function enableNonFungibleCollateral(address asset, uint256 lltv) external;
}
