// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Ampli} from "src/Ampli.sol";
import {PegToken} from "src/tokenization/PegToken.sol";
import {TestERC20} from "test/mock/TestERC20.sol";
import {OracleMock} from "test/mock/OracleMock.sol";
import {IrmMock} from "test/mock/IrmMock.sol";
import {ActionsRouter} from "test/utils/ActionsRouter.sol";
import {V4MiniRouter} from "test/utils/V4MiniRouter.sol";
import {V4RouterHelper} from "test/utils/V4RouterHelper.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract Deployers is Test {
    Ampli public ampli;
    ActionsRouter public actionsRouter;
    IPoolManager public manager;
    TestERC20 public tokenMock;
    IrmMock public irm;
    OracleMock public oracle;
    V4MiniRouter public v4MiniRouter;
    V4RouterHelper public v4RouterHelper;

    function deployAmpliWithActionRouter() public {
        address mockAmpli = address(0xFb46d30c9B3ACc61d714D167179748FD01E09aC0);
        vm.label(mockAmpli, "Ampli");
        deployCodeTo("Ampli.sol", abi.encode(address(0x498581fF718922c3f8e6A244956aF099B2652b2b)), mockAmpli);
        ampli = Ampli(mockAmpli);

        v4MiniRouter = new V4MiniRouter(address(manager));
        v4RouterHelper = new V4RouterHelper(v4MiniRouter);
        actionsRouter = new ActionsRouter(ampli, v4RouterHelper);
    }

    function deployFreshManager() public {
        vm.label(address(0x498581fF718922c3f8e6A244956aF099B2652b2b), "V4PoolManager");
        manager = IPoolManager(address(0x498581fF718922c3f8e6A244956aF099B2652b2b));
    }

    function deployMockERC20() public {
        tokenMock = new TestERC20{salt: hex"0ff0"}("Test Token", "TST", 18);
    }

    function deployIrmAndOracle() public {
        irm = new IrmMock();
        oracle = new OracleMock();
    }
}
