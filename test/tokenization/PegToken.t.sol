// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PegToken} from "src/tokenization/PegToken.sol";
import {TestERC20} from "../mock/TestERC20.sol";

contract PegTokenTest is Test {
    PegToken public pegToken;
    TestERC20 public testToken;

    function setUp() public {
        testToken = new TestERC20("Test Token", "TST", 18);

        pegToken = new PegToken(address(testToken), address(this));
    }

    function test_init() public view {
        assertEq(pegToken.name(), "Ampli Peg Test Token");
        assertEq(pegToken.symbol(), "pTST");
        assertEq(pegToken.decimals(), 18);
    }
}
