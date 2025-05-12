// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

library Math {
    uint256 constant PERCENTAGE_PRECISION = 1e6; // 1% percentage

    /// @dev Returns (`x` * `y`) / `d` rounded down.
    function mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y) / d;
    }

    /// @dev Returns (`x` * `y`) / `d` rounded up.
    function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y + (d - 1)) / d;
    }

    /// @dev Returns (`x` * `y`) / `PERCENTAGE_PRECISION` rounded down.
    function mulPercentDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y) / PERCENTAGE_PRECISION;
    }

    /// @dev Returns (`x` * `y`) / `PERCENTAGE_PRECISION` rounded up.
    function mulPercentUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y + (PERCENTAGE_PRECISION - 1)) / PERCENTAGE_PRECISION;
    }
}
