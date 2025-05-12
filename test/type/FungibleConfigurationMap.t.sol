// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FungibleConfigurationMap} from "../../src/types/FungibleConfigurationMap.sol";

contract FungibleConfigurationMapTest is Test {
    FungibleConfigurationMap public self;

    function test_fuzz_fungibleConfigurationMap_pack_unpack(uint8 _index) public {
        assertTrue(self.isZero());

        self.setAssetAsCollateral(_index, true);
        assertTrue(self.isUsingAsCollateral(_index));
        assertFalse(self.isZero());

        self.setAssetAsCollateral(_index, false);
        assertFalse(self.isUsingAsCollateral(_index));
        assertTrue(self.isZero());
    }
}
