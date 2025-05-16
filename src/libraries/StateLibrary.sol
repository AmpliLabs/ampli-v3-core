// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {BorrowShare} from "../types/BorrowShare.sol";
import {IAmpli} from "../interfaces/IAmpli.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

library StateLibrary {
    bytes32 public constant POOLS_SLOT = bytes32(uint256(0));
    uint256 public constant BORROW_ASSET_OFFSET = 4;
    uint256 public constant BORROW_SHARE_OFFSET = 5;
    function _getPoolStateSlot(PoolId poolId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(PoolId.unwrap(poolId), POOLS_SLOT));
    }

    function getPoolBorrow(IAmpli ampli, PoolId poolId) internal view returns (uint256 totalBorrowAssets, BorrowShare totalBorrowShare) {
        bytes32 stateSlot = _getPoolStateSlot(poolId);
        bytes32 slot = bytes32(uint256(stateSlot) + BORROW_ASSET_OFFSET);
        totalBorrowAssets = uint256(ampli.extsload(slot));

        slot = bytes32(uint256(stateSlot) + BORROW_SHARE_OFFSET);
        totalBorrowShare = BorrowShare.wrap(uint256(ampli.extsload(slot)));
    }
}
