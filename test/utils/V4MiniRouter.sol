// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";

enum V4Actions {
    MODIFY_LIQUIDITY,
    SWAP,
    SETTLE_ALL,
    TAKE_ALL
}

contract V4MiniRouter is IUnlockCallback {
    using TransientStateLibrary for IPoolManager;

    error DeltaNotNegative(Currency);

    IPoolManager public manager;

    constructor(address _manager) {
        manager = IPoolManager(_manager);
    }

    function executeV4Actions(V4Actions[] memory actions, bytes[] memory params) external payable {
        manager.unlock(abi.encode(actions, params));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        (V4Actions[] memory actions, bytes[] memory params) = abi.decode(data, (V4Actions[], bytes[]));

        for (uint256 i = 0; i < actions.length; i++) {
            V4Actions action = actions[i];
            bytes memory param = params[i];

            if (action == V4Actions.MODIFY_LIQUIDITY) {
                _modifyLiquidity(param);
            } else if (action == V4Actions.SWAP) {
                _swap(param);
            } else if (action == V4Actions.SETTLE_ALL) {
                _settleAll(param);
            } else if (action == V4Actions.TAKE_ALL) {
                _takeAll(param);
            }
        }
        return "";
    }

    function _modifyLiquidity(bytes memory params) internal {
        (PoolKey memory key, IPoolManager.ModifyLiquidityParams memory param) =
            abi.decode(params, (PoolKey, IPoolManager.ModifyLiquidityParams));
        manager.modifyLiquidity(key, param, "");
    }

    function _getFullDebt(Currency currency) internal view returns (uint256 amount) {
        int256 _amount = manager.currencyDelta(address(this), currency);
        if (_amount > 0) revert DeltaNotNegative(currency);
        amount = uint256(-_amount);
    }

    function _settleAll(bytes memory params) internal {
        (address from, Currency currency) = abi.decode(params, (address, Currency));
        uint256 amount = _getFullDebt(currency);

        manager.sync(currency);
        IERC20Minimal(Currency.unwrap(currency)).transferFrom(from, address(manager), amount);
        manager.settle();
    }

    function _getFullCredit(Currency currency) internal view returns (uint256 amount) {
        int256 _amount = manager.currencyDelta(address(this), currency);
        if (_amount < 0) revert DeltaNotNegative(currency);
        amount = uint256(_amount);
    }

    function _takeAll(bytes memory params) internal {
        (address to, Currency currency) = abi.decode(params, (address, Currency));
        uint256 amount = _getFullCredit(currency);

        manager.take(currency, to, amount);
    }

    function _swap(bytes memory params) internal {
        (PoolKey memory key, IPoolManager.SwapParams memory param) =
            abi.decode(params, (PoolKey, IPoolManager.SwapParams));
        manager.swap(key, param, "");
    }
}
