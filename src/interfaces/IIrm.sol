// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {InterestRate} from "../types/InterestRate.sol";

interface IIrm {
    function borrowRate(PoolKey calldata poolKey) external view returns (InterestRate);
}
