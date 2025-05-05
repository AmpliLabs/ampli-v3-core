// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Math} from "../libraries/Math.sol";

/// @notice Interest rate in Ray
type InterestRate is uint256;

using InterestRateLibrary for InterestRate global;

library InterestRateLibrary {
    uint256 constant SECONDS_PER_YEAR = 365 days;
    uint256 constant RAY = 1e27;
    uint256 constant HALF_RAY = 0.5e27;

    /// @dev Returns the product of two rays rounded up to the nearest ray
    function rayMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - HALF_RAY) / b
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_RAY), b))))) { revert(0, 0) }

            c := div(add(mul(a, b), HALF_RAY), RAY)
        }
    }

    function compound(InterestRate rate, uint256 principal, uint256 elapsed) internal pure returns (uint256) {
        uint256 expMinusOne;
        uint256 expMinusTwo;
        uint256 basePowerTwo;
        uint256 basePowerThree;
        unchecked {
            expMinusOne = elapsed - 1;

            expMinusTwo = elapsed > 2 ? elapsed - 2 : 0;

            basePowerTwo =
                rayMul(InterestRate.unwrap(rate), InterestRate.unwrap(rate)) / (SECONDS_PER_YEAR * SECONDS_PER_YEAR);
            basePowerThree = rayMul(basePowerTwo, InterestRate.unwrap(rate)) / SECONDS_PER_YEAR;
        }
        uint256 secondTerm = elapsed * expMinusOne * basePowerTwo;
        unchecked {
            secondTerm /= 2;
        }
        uint256 thirdTerm = elapsed * expMinusOne * expMinusTwo * basePowerThree;
        unchecked {
            thirdTerm /= 6;
        }

        uint256 compoundRate = RAY + (InterestRate.unwrap(rate) * elapsed) / SECONDS_PER_YEAR + secondTerm + thirdTerm;

        return Math.mulDivUp(principal, compoundRate, RAY);
    }
}
