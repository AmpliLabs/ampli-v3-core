// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

struct FungibleConfigurationMap {
    uint256 data;
}

using FungibleConfigurationMapLibrary for FungibleConfigurationMap global;

library FungibleConfigurationMapLibrary {
    uint256 constant MAX_RESERVES_COUNT = 256;

    error InvalidReseverIndex();

    function setAssetAsCollateral(
        FungibleConfigurationMap storage self,
        uint256 fungibleAssetId,
        bool usingAsCollateral
    ) internal {
        unchecked {
            require(fungibleAssetId < MAX_RESERVES_COUNT, InvalidReseverIndex());
            uint256 bit = 1 << fungibleAssetId;
            self.data = usingAsCollateral ? self.data | bit : self.data & ~bit;
        }
    }

    function isUsingAsCollateral(FungibleConfigurationMap storage self, uint256 fungibleAssetId)
        internal
        view
        returns (bool)
    {
        unchecked {
            require(fungibleAssetId < MAX_RESERVES_COUNT, InvalidReseverIndex());
            uint256 bit = 1 << fungibleAssetId;
            return (self.data & bit) != 0;
        }
    }
}
