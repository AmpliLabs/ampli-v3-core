// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IPegTokenFactory {
    function createPegToken(address underlying, address owner, bytes32 salt) external returns (address pegToken);
    function isPegToken(address pegToken) external view returns (bool);
}
