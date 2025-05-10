// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {PoolId} from "v4-core/types/PoolId.sol";

library Locker {
    error AlreadyUnlocked();

    // bytes32(uint256(keccak256("Unlocked")) - 1)
    bytes32 internal constant IS_UNLOCKED_SLOT = 0xc090fc4683624cfc3884e9d8de5eca132f2d0ec062aff75d43c0465d5ceeab23;

    // bytes32(uint256(keccak256("CheckOutItems")) - 1)
    bytes32 internal constant CHECKOUT_ITEMS_SLOT = 0xfca19f967a318694d10211587d46baac459268a91c347a0dee3aa796fc19f0db;

    function unlock() internal {
        assembly ("memory-safe") {
            // unlock
            tstore(IS_UNLOCKED_SLOT, true)
        }
    }

    function lock() internal {
        assembly ("memory-safe") {
            tstore(IS_UNLOCKED_SLOT, false)
            tstore(CHECKOUT_ITEMS_SLOT, 0)
        }
    }

    function isUnlocked() internal view returns (bool unlocked) {
        assembly ("memory-safe") {
            unlocked := tload(IS_UNLOCKED_SLOT)
        }
    }

    function checkOutItems(PoolId id, uint256 positionId) internal {
        assembly ("memory-safe") {
            let len := tload(CHECKOUT_ITEMS_SLOT)

            let slot := add(CHECKOUT_ITEMS_SLOT, mul(len, 64))
            tstore(add(slot, 32), id)
            tstore(add(slot, 64), positionId)
            tstore(CHECKOUT_ITEMS_SLOT, add(len, 1))
        }
    }

    function itemsLength() internal view returns (uint256 len) {
        assembly ("memory-safe") {
            len := tload(CHECKOUT_ITEMS_SLOT)
        }
    }

    function getCheckOutItem(uint256 index) internal view returns (PoolId id, uint256 positionId) {
        assembly ("memory-safe") {
            let slot := add(CHECKOUT_ITEMS_SLOT, mul(index, 64))
            id := tload(add(slot, 32))
            positionId := tload(add(slot, 64))
        }
    }
}
