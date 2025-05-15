// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {V4MiniRouter, V4Actions} from "./V4MiniRouter.sol";

contract V4RouterHelper {
    V4MiniRouter router;

    constructor(V4MiniRouter _router) {
        router = _router;
    }

    function addLiquidity(address sender, PoolKey memory poolKey) public {
        IPoolManager.ModifyLiquidityParams memory liquidityParam =
            IPoolManager.ModifyLiquidityParams({tickLower: -1, tickUpper: 1, liquidityDelta: 10000500 ether, salt: ""});

        V4Actions[] memory actions = new V4Actions[](3);
        bytes[] memory params = new bytes[](3);

        actions[0] = V4Actions.MODIFY_LIQUIDITY;
        params[0] = abi.encode(poolKey, liquidityParam);

        actions[1] = V4Actions.SETTLE_ALL;
        params[1] = abi.encode(sender, Currency.unwrap(poolKey.currency0));

        actions[2] = V4Actions.SETTLE_ALL;
        params[2] = abi.encode(sender, Currency.unwrap(poolKey.currency1));

        router.executeV4Actions(actions, params);
    }

    function swap(address sender, PoolKey memory poolKey, int256 amountSpecified) public {
        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: 79224201403219477170569942574
        });

        V4Actions[] memory actions = new V4Actions[](3);
        bytes[] memory params = new bytes[](3);

        actions[0] = V4Actions.SWAP;
        params[0] = abi.encode(poolKey, swapParams);

        actions[1] = V4Actions.TAKE_ALL;
        params[1] = abi.encode(sender, Currency.unwrap(poolKey.currency1));

        actions[2] = V4Actions.SETTLE_ALL;
        params[2] = abi.encode(sender, Currency.unwrap(poolKey.currency0));

        router.executeV4Actions(actions, params);
    }
}
