// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Ampli} from "src/Ampli.sol";
import {PegToken} from "src/tokenization/PegToken.sol";
import {TestERC20} from "test/mock/TestERC20.sol";
import {OracleMock} from "test/mock/OracleMock.sol";
import {IrmMock} from "test/mock/IrmMock.sol";
import {ActionsRouter} from "test/utils/ActionsRouter.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract Deployers is Test {
    Ampli public ampli;
    ActionsRouter public actionsRouter;
    IPoolManager public manager;
    TestERC20 public tokenMock;
    IrmMock public irm;
    OracleMock public oracle;

    function deployAmpliWithActionRouter() public {
        address mockAmpli = address(0xFb46d30c9B3ACc61d714D167179748FD01E09aC0);
        vm.label(mockAmpli, "Ampli");
        deployCodeTo("Ampli.sol", abi.encode(address(0x498581fF718922c3f8e6A244956aF099B2652b2b)), mockAmpli);
        ampli = Ampli(mockAmpli);
        actionsRouter = new ActionsRouter(ampli);
    }

    function deployFreshManager() public {
        manager = IPoolManager(address(0x498581fF718922c3f8e6A244956aF099B2652b2b));
    }

    function deployMockERC20() public {
        tokenMock = new TestERC20("Test Token", "TST", 18);
    }

    function deployIrmAndOracle() public {
        irm = new IrmMock();
        oracle = new OracleMock();
    }
}
