// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAmpli} from "src/interfaces/IAmpli.sol";
import {Script} from "forge-std/Script.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {BorrowShare, BorrowShareLibrary} from "src/types/BorrowShare.sol";
import {Actions, ActionsRouter} from "test/utils/ActionsRouter.sol";
import {StateLibrary} from "src/libraries/StateLibrary.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import {TestERC20} from "test/mock/TestERC20.sol";

contract BorrowActionScript is Script {
    using StateLibrary for IAmpli;

    address public deployer;
    IPoolManager public manager = IPoolManager(address(0x498581fF718922c3f8e6A244956aF099B2652b2b));
    IAmpli public ampli = IAmpli(address(0x2FE11aaEc590FFeD4E56C31303987C1d7a498ac0));
    TestERC20 public tokenMock = TestERC20(address(0xC546DE80e76E62c849eD0Af412354E588DA5DfA5));
    ActionsRouter public actionsRouter = ActionsRouter(address(0x52653db72738652389088540f42F5b17435063BD));
    PoolKey public poolKey;

    function setUp() public {
        deployer = vm.envAddress("DEPLOY_ADDRESS");

        vm.label(address(0xC546DE80e76E62c849eD0Af412354E588DA5DfA5), "TestToken");
        vm.label(address(0x8AB3F86DE96cB1AcCB533DFA5099a945Ec2ec764), "PegToken");
        poolKey = PoolKey({
            currency0: Currency.wrap(address(0x8AB3F86DE96cB1AcCB533DFA5099a945Ec2ec764)),
            currency1: Currency.wrap(address(0xC546DE80e76E62c849eD0Af412354E588DA5DfA5)),
            fee: 100, // 0.01%
            tickSpacing: 1,
            hooks: IHooks(address(ampli))
        });
    }

    function run() public {
        vm.createSelectFork("Base");
        (uint256 totalBorrow, BorrowShare totalShare) = IAmpli(address(ampli)).getPoolBorrow(poolKey.toId());

        BorrowShare borrowed = BorrowShareLibrary.toSharesDown(10 ether, totalBorrow, totalShare);

        vm.startBroadcast(vm.envUint("DEPLOY_PRIVATE"));

        ampli.updateAuthorization(poolKey, 2, deployer, address(actionsRouter));

        tokenMock.mint(deployer, 20 ether);
        tokenMock.approve(address(ampli), type(uint256).max);

        ampli.supplyFungibleCollateral(poolKey, 2, 0, 20 ether);

        Actions[] memory actions = new Actions[](3);
        bytes[] memory params = new bytes[](3);

        actions[0] = Actions.BORROW;
        params[0] = abi.encode(poolKey, 2, borrowed);

        actions[1] = Actions.V4_SWAP;
        params[1] = abi.encode(poolKey, -10 ether);

        actions[2] = Actions.SUPPLY_FUNGIBLE_COLLATERAL;
        params[2] = abi.encode(poolKey, 2, 0, 0);

        actionsRouter.executeActions(actions, params);

        vm.stopBroadcast();
    }
}
