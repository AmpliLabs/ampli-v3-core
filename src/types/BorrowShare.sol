// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Math} from "../libraries/Math.sol";

type BorrowShare is uint256;

using {add as +, minus as -} for BorrowShare global;
using BorrowShareLibrary for BorrowShare global;

function add(BorrowShare a, BorrowShare b) pure returns (BorrowShare) {
    return BorrowShare.wrap(BorrowShare.unwrap(a) + BorrowShare.unwrap(b));
}

function minus(BorrowShare a, BorrowShare b) pure returns (BorrowShare) {
    return BorrowShare.wrap(BorrowShare.unwrap(a) - BorrowShare.unwrap(b));
}

library BorrowShareLibrary {
    using Math for uint256;

    /// @dev The number of virtual shares has been chosen low enough to prevent overflows, and high enough to ensure
    /// high precision computations.
    /// @dev Virtual shares can never be redeemed for the assets they are entitled to, but it is assumed the share price
    /// stays low enough not to inflate these assets to a significant value.
    /// @dev Warning: The assets to which virtual borrow shares are entitled behave like unrealizable bad debt.
    uint256 internal constant VIRTUAL_SHARES = 1e6;

    /// @dev A number of virtual assets of 1 enforces a conversion rate between shares and assets when a market is
    /// empty.
    uint256 internal constant VIRTUAL_ASSETS = 1;

    /// @dev Calculates the value of `assets` quoted in shares, rounding down.
    function toSharesDown(uint256 assets, uint256 totalAssets, BorrowShare totalShares)
        internal
        pure
        returns (BorrowShare)
    {
        return BorrowShare.wrap(
            assets.mulDivDown(BorrowShare.unwrap(totalShares) + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS)
        );
    }

    /// @dev Calculates the value of `shares` quoted in assets, rounding down.
    function toAssetsDown(BorrowShare shares, uint256 totalAssets, BorrowShare totalShares)
        internal
        pure
        returns (uint256)
    {
        return BorrowShare.unwrap(shares).mulDivDown(
            totalAssets + VIRTUAL_ASSETS, BorrowShare.unwrap(totalShares) + VIRTUAL_SHARES
        );
    }

    /// @dev Calculates the value of `assets` quoted in shares, rounding up.
    function toSharesUp(uint256 assets, uint256 totalAssets, BorrowShare totalShares)
        internal
        pure
        returns (BorrowShare)
    {
        return BorrowShare.wrap(
            assets.mulDivUp(BorrowShare.unwrap(totalShares) + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS)
        );
    }

    /// @dev Calculates the value of `shares` quoted in assets, rounding up.
    function toAssetsUp(BorrowShare shares, uint256 totalAssets, BorrowShare totalShares)
        internal
        pure
        returns (uint256)
    {
        return BorrowShare.unwrap(shares).mulDivUp(
            totalAssets + VIRTUAL_ASSETS, BorrowShare.unwrap(totalShares) + VIRTUAL_SHARES
        );
    }
}
