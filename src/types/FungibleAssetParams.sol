// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Currency} from "v4-core/types/Currency.sol";

struct FungibleAssetParams {
    Currency asset;
    uint96 lltv;
}
