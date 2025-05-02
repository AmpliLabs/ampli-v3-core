// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {FungibleConfigurationMap} from "./FungibleConfigurationMap.sol";
import {NonFungibleAssetSet} from "./NonFungibleAssetsSet.sol";
import {NonFungibleAssetId} from "./NonFungibleAssetId.sol";

struct Position {
    uint128 borrowShares;
    FungibleConfigurationMap funibles;
    mapping(uint256 id => uint256 balance) collateralFungibleAssets;
    NonFungibleAssetSet nonFungibleAssets;
}

using PositionLibrary for Position global;

library PositionLibrary {
    error PositionAlreadyContainsNonFungibleItem();
    error PositionDoesNotContainNonFungibleItem();

    function addFungible(Position storage self, uint256 fungibleAssetId, uint256 amount) internal {
        self.collateralFungibleAssets[fungibleAssetId] += amount;

        if (!self.funibles.isUsingAsCollateral(fungibleAssetId)) {
            self.funibles.setAssetAsCollateral(fungibleAssetId, true);
        }
    }

    function removeFungible(Position storage self, uint256 fungibleAssetId, uint256 amount) internal {
        uint256 collateralAmount = self.collateralFungibleAssets[fungibleAssetId];
        uint256 updateAmount = collateralAmount - amount;

        if (updateAmount == 0) {
            self.funibles.setAssetAsCollateral(fungibleAssetId, false);
        }

        self.collateralFungibleAssets[fungibleAssetId] = updateAmount;
    }

    function addNonFungible(Position storage self, NonFungibleAssetId nonFungibleAssetId) internal {
        bool isExist = self.nonFungibleAssets.add(nonFungibleAssetId, 32);
        require(isExist, PositionAlreadyContainsNonFungibleItem());
    }

    function removeNonFungible(Position storage self, NonFungibleAssetId nonFungibleAssetId) internal {
        bool isExist = self.nonFungibleAssets.remove(nonFungibleAssetId);
        require(isExist, PositionDoesNotContainNonFungibleItem());
    }
}
