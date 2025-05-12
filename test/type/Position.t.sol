// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {OracleMock} from "../mock/OracleMock.sol";
import {Position, PositionLibrary} from "../../src/types/Position.sol";
import {NonFungibleAssetId} from "../../src/types/NonFungibleAssetId.sol";
import {FungibleAssetParams} from "../../src/types/FungibleAssetParams.sol";
import {BorrowShare} from "../../src/types/BorrowShare.sol";

contract PositionTest is Test {
    error PositionAlreadyContainsNonFungibleItem();
    error PositionDoesNotContainNonFungibleItem();

    Position public position;
    OracleMock public oracle;
    bytes32 internal _ZERO_SENTINEL = 0x0000000000000000000000000000000000000000000000fbb67fda52d4bfb8bf;

    mapping(uint256 => FungibleAssetParams) public fungibleAssetParams;
    mapping(address => uint256 lltv) public nonFungibleAssetLltv;

    function setUp() public {
        oracle = new OracleMock();
        fungibleAssetParams[0] = FungibleAssetParams({asset: address(20), lltv: 1e6});
        nonFungibleAssetLltv[address(721)] = 1e6;
    }

    function test_fuzz_addFungible(uint8 fungibleAssetId, uint256 amount) public {
        position.addFungible(fungibleAssetId, amount);

        assertTrue(position.funibles.isUsingAsCollateral(fungibleAssetId));
        assertEq(position.collateralFungibleAssets[fungibleAssetId], amount);
    }

    function test_fuzz_addAndRemovePartialFungible(uint8 fungibleAssetId, uint256 amount, uint256 amountToRemove)
        public
    {
        vm.assume(amountToRemove < amount);

        position.addFungible(fungibleAssetId, amount);
        position.removeFungible(fungibleAssetId, amountToRemove);

        assertTrue(position.funibles.isUsingAsCollateral(fungibleAssetId));
        assertEq(position.collateralFungibleAssets[fungibleAssetId], amount - amountToRemove);
    }

    function test_fuzz_addAndRemoveFungible(uint8 fungibleAssetId, uint256 amount) public {
        position.addFungible(fungibleAssetId, amount);
        position.removeFungible(fungibleAssetId, amount);

        assertFalse(position.funibles.isUsingAsCollateral(fungibleAssetId));
        assertEq(position.collateralFungibleAssets[fungibleAssetId], 0);
    }

    function test_fuzz_addNonFungible(NonFungibleAssetId assteId) public {
        vm.assume(NonFungibleAssetId.unwrap(assteId) != _ZERO_SENTINEL);

        position.addNonFungible(assteId);

        assertEq(position.nonFungibleAssets.length(), 1);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_fuzz_addDupNonFungible(NonFungibleAssetId assteId) public {
        vm.assume(NonFungibleAssetId.unwrap(assteId) != _ZERO_SENTINEL);

        position.addNonFungible(assteId);
        vm.expectRevert(PositionAlreadyContainsNonFungibleItem.selector);
        position.addNonFungible(assteId);
    }

    function test_fuzz_removeNonFungible(NonFungibleAssetId assteId) public {
        vm.assume(NonFungibleAssetId.unwrap(assteId) != _ZERO_SENTINEL);

        position.addNonFungible(assteId);
        position.removeNonFungible(assteId);

        assertEq(position.nonFungibleAssets.length(), 0);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_fuzz_removeNonFungibleNonExist(NonFungibleAssetId assteId) public {
        vm.assume(NonFungibleAssetId.unwrap(assteId) != _ZERO_SENTINEL);

        vm.expectRevert(PositionDoesNotContainNonFungibleItem.selector);
        position.removeNonFungible(assteId);
    }

    function test_fuzz_borrowAndRepay(BorrowShare borrowAmount, BorrowShare repayAmount) public {
        vm.assume(BorrowShare.unwrap(borrowAmount) >= BorrowShare.unwrap(repayAmount));

        position.borrow(borrowAmount);
        position.repay(repayAmount);

        assertEq(
            BorrowShare.unwrap(position.borrowShares),
            BorrowShare.unwrap(borrowAmount) - BorrowShare.unwrap(repayAmount)
        );
    }

    function test_fuzz_liquidate(address initOwner, address liquidator) public {
        position.owner = initOwner;
        position.liquidate(liquidator);
        assertEq(position.owner, liquidator);
    }

    function test_isHealthy() public {
        console.log(position.funibles.isZero());
        console.log(position.nonFungibleAssets.length());
        (bool isHealth, uint256 maxBorrow, uint256 borrowed) =
            position.isHealthy(fungibleAssetParams, nonFungibleAssetLltv, oracle, 1, 0, BorrowShare.wrap(0));
        console.log(isHealth);
        assertFalse(isHealth);
    }
    // function test_isNotHealthy() public {
    //     // assertFalse(position.isHealthy());
    // }
}
