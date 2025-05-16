// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IAmpli} from "src/interfaces/IAmpli.sol";
import {V4MiniRouter} from "test/utils/V4MiniRouter.sol";
import {V4RouterHelper} from "test/utils/V4RouterHelper.sol";
import {ActionsRouter} from "test/utils/ActionsRouter.sol";
import {TestERC20} from "test/mock/TestERC20.sol";
import {OracleMock} from "test/mock/OracleMock.sol";
import {IrmMock} from "test/mock/IrmMock.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BorrowShare, BorrowShareLibrary} from "src/types/BorrowShare.sol";
import {Actions} from "test/utils/ActionsRouter.sol";
import {V4Actions} from "test/utils/V4MiniRouter.sol";

contract RouterDeployScript is Script {
    IPoolManager public manager = IPoolManager(address(0x498581fF718922c3f8e6A244956aF099B2652b2b));
    IAmpli public ampli = IAmpli(address(0x2FE11aaEc590FFeD4E56C31303987C1d7a498ac0));

    V4MiniRouter public v4MiniRouter;
    V4RouterHelper public v4RouterHelper;
    ActionsRouter public actionsRouter;
    TestERC20 public tokenMock;
    IERC20 public pegToken;
    IrmMock public irm;
    OracleMock public oracle;
    PoolKey public poolKey;
    address public deployer;

    function _supplyMaxFungibleCollateral(uint256 amount) public {
        ampli.updateAuthorization(poolKey, 1, address(deployer), address(actionsRouter));

        ampli.supplyFungibleCollateral(poolKey, 1, 0, amount);
    }

    function _borrowPegToken(uint256 amount) public {
        BorrowShare borrowed = BorrowShareLibrary.toSharesDown(amount, 0, BorrowShare.wrap(0));

        Actions[] memory actions = new Actions[](2);
        bytes[] memory params = new bytes[](2);

        actions[0] = Actions.BORROW;
        params[0] = abi.encode(poolKey, 1, borrowed);

        actions[1] = Actions.TRANSFER_OUT_FUNGIBLE_ASSET;
        params[1] = abi.encode(address(pegToken), address(deployer), amount);

        actionsRouter.executeActions(actions, params);
    }

    function run() public {
        deployer = vm.envAddress("DEPLOY_ADDRESS");
        vm.createSelectFork("Base");
        vm.startBroadcast(vm.envUint("DEPLOY_PRIVATE"));

        v4MiniRouter = new V4MiniRouter(address(manager));
        v4RouterHelper = new V4RouterHelper(v4MiniRouter);
        actionsRouter = new ActionsRouter(ampli, v4RouterHelper);

        tokenMock = new TestERC20{salt: hex"0ff0"}("Test Token", "TST", 18);
        irm = new IrmMock();
        oracle = new OracleMock();

        irm.setBorrowRate(0.01 * 1e27);
        // assetId = 0, mock token price / peg token = 1
        oracle.setFungibleAssetPrice(0, 1e36);
        oracle.setFungibleAssetPrice(1, 1e36);

        ampli.initialize(address(tokenMock), deployer, irm, oracle, 2, 1, hex"ff");

        actionsRouter.approve(address(tokenMock));
        tokenMock.approve(address(ampli), type(uint256).max);
        tokenMock.approve(address(actionsRouter), type(uint256).max);
        tokenMock.approve(address(v4MiniRouter), type(uint256).max);

        pegToken = IERC20(address(0x8AB3F86DE96cB1AcCB533DFA5099a945Ec2ec764));

        poolKey = PoolKey({
            currency0: Currency.wrap(address(pegToken)),
            currency1: Currency.wrap(address(tokenMock)),
            fee: 100, // 0.01%
            tickSpacing: 1,
            hooks: IHooks(address(ampli))
        });

        ampli.updateAuthorization(poolKey, 1, address(deployer), address(actionsRouter));

        tokenMock.mint(address(deployer), 1500 ether);
        _supplyMaxFungibleCollateral(1000 ether);
        _borrowPegToken(600 ether);

        actionsRouter.approve(address(pegToken));
        pegToken.approve(address(v4MiniRouter), type(uint256).max);

        v4RouterHelper.addLiquidity(deployer, poolKey);

        vm.stopBroadcast();
    }
}
