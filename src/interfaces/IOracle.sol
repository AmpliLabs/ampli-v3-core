// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {NonFungibleAssetId} from "../types/NonFungibleAssetId.sol";

/// @title IOracle
interface IOracle {
    /// @notice Returns the price of 1 asset of collateral token quoted in 1 asset of loan token, scaled by 1e36.
    /// @dev It corresponds to the price of 10**(collateral token decimals) assets of collateral token quoted in
    /// 10**(loan token decimals) assets of loan token with `36 + loan token decimals - collateral token decimals`
    /// decimals of precision.
    function fungibleAssetPrice(uint256 fungibleAssetId) external view returns (uint256);

    /// @notice Returns the price of 1 asset of loan token quoted in NFT.
    function nonFungibleAssetPrice(NonFungibleAssetId nonFungibleAssetId) external view returns (uint256);
}
