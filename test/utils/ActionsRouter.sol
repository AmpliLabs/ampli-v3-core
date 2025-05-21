// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {V4RouterHelper} from "./V4RouterHelper.sol";
import {IAmpli} from "src/interfaces/IAmpli.sol";
import {IUnlockCallback} from "src/interfaces/callback/IUnlockCallback.sol";
import {NonFungibleAssetId} from "src/types/NonFungibleAssetId.sol";
import {BorrowShare} from "src/types/BorrowShare.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";

enum Actions {
    SUPPLY_FUNGIBLE_COLLATERAL,
    SUPPLY_NON_FUNGIBLE_COLLATERAL,
    WITHDRAW_FUNGIBLE_COLLATERAL,
    WITHDRAW_NON_FUNGIBLE_COLLATERAL,
    BORROW,
    TAKE_ALL,
    SETTLE_ALL,
    V4_SWAP
}

contract ActionsRouter is IUnlockCallback {
    using TransientStateLibrary for IAmpli;

    error DeltaNotNegative(Currency);

    IAmpli public ampli;
    V4RouterHelper public v4RouterHelper;

    constructor(IAmpli _ampli, V4RouterHelper _v4RouterHelper) {
        ampli = _ampli;
        v4RouterHelper = _v4RouterHelper;
    }

    function approve(address token) external {
        IERC20Minimal(token).approve(address(ampli), type(uint256).max);
        IERC20Minimal(token).approve(address(this), type(uint256).max);
        IERC20Minimal(token).approve(address(v4RouterHelper.router()), type(uint256).max);
    }

    function executeActions(Actions[] memory actions, bytes[] memory params) external payable {
        ampli.unlock(abi.encode(actions, params));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        (Actions[] memory actions, bytes[] memory params) = abi.decode(data, (Actions[], bytes[]));
        for (uint256 i = 0; i < actions.length; i++) {
            Actions action = actions[i];
            bytes memory param = params[i];

            if (action == Actions.SUPPLY_FUNGIBLE_COLLATERAL) {
                _supplyFungibleCollateral(param);
            } else if (action == Actions.SUPPLY_NON_FUNGIBLE_COLLATERAL) {
                _supplyNonFungibleCollateral(param);
            } else if (action == Actions.WITHDRAW_FUNGIBLE_COLLATERAL) {
                _withdrawFungibleCollateral(param);
            } else if (action == Actions.BORROW) {
                _borrow(param);
            } else if (action == Actions.V4_SWAP) {
                _swap(param);
            } else if (action == Actions.TAKE_ALL) {
                _takeAll(param);
            } else if (action == Actions.SETTLE_ALL) {
                _settleAll(param);
            }
        }
        return "";
    }

    function _supplyFungibleCollateral(bytes memory params) internal {
        (PoolKey memory key, uint256 positionId, uint256 fungibleAssetId, uint256 amount) =
            abi.decode(params, (PoolKey, uint256, uint256, uint256));

        if (fungibleAssetId == 0 && amount == 0) {
            amount = IERC20Minimal(Currency.unwrap(key.currency1)).balanceOf(address(this));
        } else if (fungibleAssetId == 1 && amount == 0) {
            amount = IERC20Minimal(Currency.unwrap(key.currency0)).balanceOf(address(this));
        }

        ampli.supplyFungibleCollateral(key, positionId, fungibleAssetId, amount);
    }

    function _supplyNonFungibleCollateral(bytes memory params) internal {
        (PoolKey memory key, uint256 positionId, NonFungibleAssetId nonFungibleAssetId) =
            abi.decode(params, (PoolKey, uint256, NonFungibleAssetId));
        ampli.supplyNonFungibleCollateral(key, positionId, nonFungibleAssetId);
    }

    function _withdrawFungibleCollateral(bytes memory params) internal {
        (PoolKey memory key, uint256 positionId, uint256 fungibleAssetId, uint256 amount) =
            abi.decode(params, (PoolKey, uint256, uint256, uint256));
        ampli.withdrawFungibleCollateral(key, positionId, fungibleAssetId, amount);
    }

    function _borrow(bytes memory params) internal {
        (PoolKey memory key, uint256 positionId, BorrowShare share) =
            abi.decode(params, (PoolKey, uint256, BorrowShare));

        ampli.borrow(key, positionId, share);
    }

    function currencyDelta(address target, Currency currency) internal view returns (int256) {
        bytes32 key;
        assembly ("memory-safe") {
            mstore(0, and(target, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(32, and(currency, 0xffffffffffffffffffffffffffffffffffffffff))
            key := keccak256(0, 64)
        }
        return int256(uint256(ampli.exttload(key)));
    }

    function _getFullCredit(Currency currency) internal view returns (uint256 amount) {
        int256 _amount = currencyDelta(address(this), currency);
        if (_amount < 0) revert DeltaNotNegative(currency);
        amount = uint256(_amount);
    }

    function _getFullDebt(Currency currency) internal view returns (uint256 amount) {
        int256 _amount = currencyDelta(address(this), currency);
        if (_amount > 0) revert DeltaNotNegative(currency);
        amount = uint256(-_amount);
    }

    function _takeAll(bytes memory params) internal {
        (address to, Currency currency) = abi.decode(params, (address, Currency));
        uint256 amount = _getFullCredit(currency);

        ampli.take(currency, to, amount);
    }

    function _settleAll(bytes memory params) internal {
        (address from, Currency currency) = abi.decode(params, (address, Currency));
        uint256 amount = _getFullDebt(currency);

        ampli.sync(currency);
        IERC20Minimal(Currency.unwrap(currency)).transferFrom(from, address(ampli), amount);
        ampli.settle();
    }

    function _swap(bytes memory params) internal {
        // Only Support peg token -> underlying
        (PoolKey memory key, int256 amountSpecified) = abi.decode(params, (PoolKey, int256));
        v4RouterHelper.swap(address(this), key, amountSpecified);
    }
}
