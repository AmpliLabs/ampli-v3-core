// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Deployers} from "./utils/Deployers.sol";
import {Actions} from "./utils/ActionsRouter.sol";
import {V4Actions} from "./utils/V4MiniRouter.sol";
import {IAmpli} from "src/interfaces/IAmpli.sol";
import {StateLibrary} from "src/libraries/StateLibrary.sol";
import {BorrowShare, BorrowShareLibrary} from "src/types/BorrowShare.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract AmpliTest is Test, Deployers {
    using StateLibrary for IAmpli;

    PoolKey public poolKey;
    IERC20 public pegToken;

    function setUp() public {
        vm.createSelectFork("Base", 30177975);
        deployFreshManager();
        deployAmpliWithActionRouter();
        deployMockERC20();
        deployIrmAndOracle();

        poolKey = PoolKey({
            currency0: Currency.wrap(address(0xA19570ac9E7bB35eAABe7a2e97B2941c200b3667)),
            currency1: Currency.wrap(address(tokenMock)),
            fee: 100, // 0.01%
            tickSpacing: 1,
            hooks: IHooks(address(0xFb46d30c9B3ACc61d714D167179748FD01E09aC0))
        });

        pegToken = IERC20(address(0xA19570ac9E7bB35eAABe7a2e97B2941c200b3667));

        ampli.initialize(address(tokenMock), address(this), irm, oracle, 2, 1, hex"ff");

        actionsRouter.approve(address(tokenMock));
        actionsRouter.approve(address(pegToken));

        irm.setBorrowRate(0.01 * 1e27);
        // assetId = 0, mock token price / peg token = 1
        oracle.setFungibleAssetPrice(0, 1e36);
        oracle.setFungibleAssetPrice(1, 1e36);

        // Approve
        tokenMock.approve(address(ampli), type(uint256).max);
        tokenMock.approve(address(actionsRouter), type(uint256).max);
        tokenMock.approve(address(v4MiniRouter), type(uint256).max);
        pegToken.approve(address(v4MiniRouter), type(uint256).max);
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

        actionsRouter.executeActions(actions, params);

        assertEq(tokenMock.balanceOf(address(this)), 1 ether);
    }

    function test_borrow() public {
        ampli.updateAuthorization(poolKey, 1, address(this), address(actionsRouter));
        tokenMock.mint(address(this), 10 ether);

        ampli.supplyFungibleCollateral(poolKey, 1, 0, 10 ether);
        BorrowShare borrowed = BorrowShareLibrary.toSharesDown(1 ether, 0, BorrowShare.wrap(0));

        Actions[] memory actions = new Actions[](1);
        bytes[] memory params = new bytes[](1);

        actions[0] = Actions.BORROW;
        params[0] = abi.encode(poolKey, 1, borrowed);

        actionsRouter.executeActions(actions, params);

        assertEq(pegToken.balanceOf(address(actionsRouter)), 1 ether);
    }

    function _supplyMaxFungibleCollateral(uint256 amount) public {
        ampli.updateAuthorization(poolKey, 1, address(this), address(actionsRouter));

        ampli.supplyFungibleCollateral(poolKey, 1, 0, amount);
    }

    function _borrowPegToken(uint256 amount) public {
        BorrowShare borrowed = BorrowShareLibrary.toSharesDown(amount, 0, BorrowShare.wrap(0));

        Actions[] memory actions = new Actions[](2);
        bytes[] memory params = new bytes[](2);

        actions[0] = Actions.BORROW;
        params[0] = abi.encode(poolKey, 1, borrowed);

        actions[1] = Actions.TRANSFER_OUT_FUNGIBLE_ASSET;
        params[1] = abi.encode(address(pegToken), address(this), amount);

        actionsRouter.executeActions(actions, params);
    }

    function test_borrowAndSupply() public {
        tokenMock.mint(address(this), 1500 ether);
        _supplyMaxFungibleCollateral(1000 ether);
        _borrowPegToken(600 ether);
        v4RouterHelper.addLiquidity(address(this), poolKey);

        address user = makeAddr("user");
        vm.startPrank(user);
        ampli.updateAuthorization(poolKey, 2, user, address(actionsRouter));

        tokenMock.mint(user, 1 ether);
        tokenMock.approve(address(ampli), type(uint256).max);
        ampli.supplyFungibleCollateral(poolKey, 2, 0, 0.5 ether);

        (uint256 totalBorrow, BorrowShare totalShare) = IAmpli(address(ampli)).getPoolBorrow(poolKey.toId());

        BorrowShare borrowed = BorrowShareLibrary.toSharesDown(5 ether, totalBorrow, totalShare);

        Actions[] memory actions = new Actions[](3);
        bytes[] memory params = new bytes[](3);

        actions[0] = Actions.BORROW;
        params[0] = abi.encode(poolKey, 2, borrowed);

        actions[1] = Actions.V4_SWAP;
        params[1] = abi.encode(poolKey, -5 ether);

        actions[2] = Actions.SUPPLY_FUNGIBLE_COLLATERAL;
        params[2] = abi.encode(poolKey, 2, 0, 0);

        actionsRouter.executeActions(actions, params);
        vm.stopPrank();
    }
}
