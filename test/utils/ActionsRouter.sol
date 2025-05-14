// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IAmpli} from "src/interfaces/IAmpli.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import {IUnlockCallback} from "src/interfaces/callback/IUnlockCallback.sol";
import {NonFungibleAssetId} from "src/types/NonFungibleAssetId.sol";
import {BorrowShare} from "src/types/BorrowShare.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

enum Actions {
    TRANSFER_IN_FUNGIBLE_ASSET,
    TRANSFER_OUT_FUNGIBLE_ASSET,
    SUPPLY_FUNGIBLE_COLLATERAL,
    SUPPLY_NON_FUNGIBLE_COLLATERAL,
    WITHDRAW_FUNGIBLE_COLLATERAL,
    WITHDRAW_NON_FUNGIBLE_COLLATERAL,
    BORROW
}

contract ActionsRouter is IUnlockCallback {
    IAmpli public ampli;

    constructor(IAmpli _ampli) {
        ampli = _ampli;
    }

    function approve(address token) external {
        IERC20(token).approve(address(ampli), type(uint256).max);
    }

    function executeActions(Actions[] memory actions, bytes[] memory params) external payable {
        ampli.unlock(abi.encode(actions, params));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        (Actions[] memory actions, bytes[] memory params) = abi.decode(data, (Actions[], bytes[]));
        for (uint256 i = 0; i < actions.length; i++) {
            Actions action = actions[i];
            bytes memory param = params[i];

            if (action == Actions.TRANSFER_IN_FUNGIBLE_ASSET) {
                _transferInFungibleAsset(param);
            } else if (action == Actions.TRANSFER_OUT_FUNGIBLE_ASSET) {
                _transferOutFungibleAsset(param);
            } else if (action == Actions.SUPPLY_FUNGIBLE_COLLATERAL) {
                _supplyFungibleCollateral(param);
            } else if (action == Actions.SUPPLY_NON_FUNGIBLE_COLLATERAL) {
                _supplyNonFungibleCollateral(param);
            } else if (action == Actions.WITHDRAW_FUNGIBLE_COLLATERAL) {
                _withdrawFungibleCollateral(param);
            } else if (action == Actions.BORROW) {
                _borrow(param);
            }
        }
        return "";
    }

    function _transferInFungibleAsset(bytes memory params) internal {
        (address currency, address from, uint256 amount) = abi.decode(params, (address, address, uint256));
        IERC20(currency).transferFrom(from, address(this), amount);
    }

    function _transferOutFungibleAsset(bytes memory params) internal {
        (address currency, address to, uint256 amount) = abi.decode(params, (address, address, uint256));
        IERC20(currency).transfer(to, amount);
    }

    function _supplyFungibleCollateral(bytes memory params) internal {
        (PoolKey memory key, uint256 positionId, uint256 fungibleAssetId, uint256 amount) =
            abi.decode(params, (PoolKey, uint256, uint256, uint256));

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
        (PoolKey memory key, uint256 positionId, address receiver, BorrowShare share) =
            abi.decode(params, (PoolKey, uint256, address, BorrowShare));

        ampli.borrow(key, positionId, receiver, share);
    }
}
