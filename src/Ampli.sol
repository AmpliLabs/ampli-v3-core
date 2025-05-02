// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IAmpli} from "./interfaces/IAmpli.sol";

contract Ampli is IAmpli {
    mapping(uint256 => address) internal _reservesList;
}
