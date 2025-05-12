// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IOracle} from "src/interfaces/IOracle.sol";
import {NonFungibleAssetId} from "src/types/NonFungibleAssetId.sol";

contract OracleMock is IOracle {
    mapping(uint256 => uint256) public mockFungibleAssetPrice;
    uint256 public mockNonFungibleAssetPrice;

    function setFungibleAssetPrice(uint256 fungibleAssetId, uint256 price) public {
        mockFungibleAssetPrice[fungibleAssetId] = price;
    }

    function setNonFungibleAssetPrice(uint256 price) public {
        mockNonFungibleAssetPrice = price;
    }

    function fungibleAssetPrice(uint256 fungibleAssetId) external view returns (uint256) {
        return mockFungibleAssetPrice[fungibleAssetId];
    }

    function nonFungibleAssetPrice(NonFungibleAssetId) external view returns (uint256) {
        return mockNonFungibleAssetPrice;
    }
}
