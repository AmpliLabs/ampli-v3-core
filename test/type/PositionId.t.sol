// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PositionId, PositionIdLibrary} from "../../src/types/PositionId.sol";

contract OrderIdTest is Test {
    function test_fuzz_orderId_pack_unpack(address owner, uint64 index) public pure {
        PositionId positionId = PositionIdLibrary.toPositionId(owner, index);

        assertEq(positionId.owner(), owner);
        assertEq(positionId.index(), index);
    }
}
