// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {PegToken} from "./tokenization/PegToken.sol";

contract PegTokenFactory {
    function createPegToken(address underlying, address owner, bytes32 salt) external returns (address pegToken) {
        pegToken = address(new PegToken{salt: salt}(underlying, owner));
    }
}
