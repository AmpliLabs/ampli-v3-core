// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

// TODO: Use Currency in Uniswap v4 to replace asset
struct FungibleAssetParams {
    address asset;
    uint96 lltv;
}
