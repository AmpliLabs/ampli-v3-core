// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Locker} from "src/types/Locker.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {console} from "forge-std/console.sol";

contract LockerTest is Test {
    struct GlobalPosition {
        PoolId id;
        uint256 positionId;
    }

    function test_fuzz_locker(PoolId _id, uint256 _positionId) public {
        Locker.checkOutItems(_id, _positionId);

        (PoolId id, uint256 positionId) = Locker.getCheckOutItem(0);
        assertEq(PoolId.unwrap(id), PoolId.unwrap(id));
        assertEq(positionId, positionId);
    }

    function test_fuzz_locker_insert(GlobalPosition[] memory positions) public {
        for (uint256 i = 0; i < positions.length; i++) {
            console.log(i);
            Locker.checkOutItems(positions[i].id, positions[i].positionId);

            (PoolId poolId, uint256 positionId) = Locker.getCheckOutItem(i);
            assertEq(positions[i].positionId, positionId);

            assertEq(PoolId.unwrap(positions[i].id), PoolId.unwrap(poolId));
        }

        assertEq(Locker.itemsLength(), positions.length);

        Locker.lock();
        assertEq(Locker.itemsLength(), 0);
    }
}
