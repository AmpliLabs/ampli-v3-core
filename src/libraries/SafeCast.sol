// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

library SafeCast {
    error SafeCastOverflow();

    /// @notice Cast a int256 to a int128, revert on overflow or underflow
    /// @param x The int256 to be downcasted
    /// @return y The downcasted integer, now type int128
    function toInt128(uint256 x) internal pure returns (int128 y) {
        require(x < 1 << 127, SafeCastOverflow());
        y = int128(int256(x));
    }
    
    /// @notice Cast a int256 to a int128, revert on overflow or underflow
    /// @param x The int256 to be downcasted
    /// @return y The downcasted integer, now type int128
    function toInt128(int256 x) internal pure returns (int128 y) {
        y = int128(x);
        require(x == y, SafeCastOverflow());
    }
}
