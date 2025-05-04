// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IOracle} from "../interfaces/IOracle.sol";
import {FungibleConfigurationMap} from "./FungibleConfigurationMap.sol";
import {NonFungibleAssetSet} from "./NonFungibleAssetsSet.sol";
import {NonFungibleAssetId} from "./NonFungibleAssetId.sol";
import {Math} from "../libraries/Math.sol";
import {FungibleAssetParams} from "./FungibleAssetParams.sol";
import {BorrowShare} from "./BorrowShare.sol";

struct Position {
    address owner;
    BorrowShare borrowShares;
    FungibleConfigurationMap funibles;
    mapping(uint256 id => uint256 balance) collateralFungibleAssets;
    NonFungibleAssetSet nonFungibleAssets;
}

using PositionLibrary for Position global;

library PositionLibrary {
    using Math for uint256;

    error PositionAlreadyContainsNonFungibleItem();
    error PositionDoesNotContainNonFungibleItem();

    uint256 constant ORACLE_PRICE_SCALE = 1e36;

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

    function borrow(Position storage self, BorrowShare share) internal {
        self.borrowShares = self.borrowShares + share;
    }

    function isHealthy(
        Position storage self,
        mapping(uint256 => FungibleAssetParams) storage fungibleAssetParams,
        mapping(address => uint256 lltv) storage nonFungibleAssetLltv,
        IOracle oracle,
        uint256 reserveCount,
        uint256 totalBorrowAsset,
        BorrowShare totalBorrowShare
    ) internal view returns (bool) {
        if (self.funibles.isZero() && (self.nonFungibleAssets.length() > 0)) {
            return false;
        }

        uint256 borrowed = self.borrowShares.toAssetsUp(totalBorrowAsset, totalBorrowShare);
        uint256 maxBorrow = 0;

        for (uint256 i = 0; i < reserveCount; i++) {
            if (self.funibles.isUsingAsCollateral(i)) {
                uint256 collateral = self.collateralFungibleAssets[i];
                uint256 collateralPrice = oracle.fungibleAssetPrice(i);

                maxBorrow += collateral.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).mulPercentDown(
                    fungibleAssetParams[i].lltv
                );
            }
        }

        if (maxBorrow >= borrowed) {
            return true;
        } else {
            for (uint256 i = 0; i < self.nonFungibleAssets.length(); i++) {
                NonFungibleAssetId collateral = self.nonFungibleAssets.at(i);

                uint256 collateralPrice = oracle.nonFungibleAssetPrice(collateral);

                maxBorrow += collateralPrice.mulPercentDown(nonFungibleAssetLltv[collateral.nft()]);
            }

            return maxBorrow >= borrowed;
        }
    }
}
