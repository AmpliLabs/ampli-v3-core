// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/// @dev Layout: address owner | 32 empty | uint64 index
type PositionId is bytes32;

using PositionIdLibrary for PositionId global;

library PositionIdLibrary {
    uint64 private constant MASK_64_BITS = 0xFFFFFFFFFFFFFFFF;

    // #### GETTERS ####
    function owner(PositionId self) internal pure returns (address _owner) {
        assembly ("memory-safe") {
            _owner := shr(96, self)
        }
    }

    function index(PositionId self) internal pure returns (uint64 _index) {
        assembly ("memory-safe") {
            _index := and(self, MASK_64_BITS)
        }
    }

    // #### SETTERS ####
    function toPositionId(address _owner, uint64 _index) internal pure returns (PositionId id) {
        assembly ("memory-safe") {
            id := or(shl(96, _owner), and(_index, MASK_64_BITS))
        }
    }
}
