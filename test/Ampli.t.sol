// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Actions} from "./utils/ActionsRouter.sol";
import {Pool} from "src/types/Pool.sol";
import {Deployers} from "./utils/Deployers.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

contract PoolTest is Test, Deployers {
    Pool public pool;
    PoolKey public poolKey;

    function setUp() public {
        vm.createSelectFork("Base", 30177975);
        deployAmpliWithActionRouter();
        deployFreshManager();
        deployMockERC20();
        deployIrmAndOracle();

        poolKey = PoolKey({
            currency0: Currency.wrap(address(0x03e213441dCcC2344E11D7b713FeaAAe4E60813D)),
            currency1: Currency.wrap(address(tokenMock)),
            fee: 100, // 0.01%
            tickSpacing: 1,
            hooks: IHooks(address(0xFb46d30c9B3ACc61d714D167179748FD01E09aC0))
        });

        actionsRouter.approve(address(tokenMock));
        ampli.initialize(address(tokenMock), address(this), irm, oracle, 2, 1, hex"ff");
        irm.setBorrowRate(0.01 * 1e27);
    }

    function test_supplyAndWithdrawFungibleCollateral() public {
        ampli.updateAuthorization(poolKey, 1, address(this), address(actionsRouter));

        Actions[] memory actions = new Actions[](4);
        bytes[] memory params = new bytes[](4);

        actions[0] = Actions.TRANSFER_IN_FUNGIBLE_ASSET;
        params[0] = abi.encode(address(tokenMock), address(this), 1 ether);

        actions[1] = Actions.SUPPLY_FUNGIBLE_COLLATERAL;
        params[1] = abi.encode(poolKey, 1, 0, 1 ether);

        actions[2] = Actions.WITHDRAW_FUNGIBLE_COLLATERAL;
        params[2] = abi.encode(poolKey, 1, 0, 1 ether);

        actions[3] = Actions.TRANSFER_OUT_FUNGIBLE_ASSET;
        params[3] = abi.encode(address(tokenMock), address(this), 1 ether);

        tokenMock.mint(address(this), 1 ether);
        tokenMock.approve(address(actionsRouter), 1 ether);

        actionsRouter.executeActions(actions, params);

        assertEq(tokenMock.balanceOf(address(this)), 1 ether);
    }
}
