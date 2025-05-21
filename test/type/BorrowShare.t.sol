// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {BorrowShare, BorrowShareLibrary} from "src/types/BorrowShare.sol";

contract BorrowShareTest is Test {
    function test_borrowShare() pure public {
        uint256 totalAssets = 0x855b78ac1bee6c7896; 
        BorrowShare totalShares = BorrowShare.wrap(0x1fcb750ab91af98767394f4);

        // uint256 asset = shares.toAssetsDown(totalAssets, totalShares);
        BorrowShare targetShare = BorrowShareLibrary.toSharesUp(20000021651469402337, totalAssets, totalShares);
        // BorrowShare targetShare = BorrowShare.wrap(2499991688074270153234454);
        // uint256 asset = targetShare.toAssetsDown(totalAssets, totalShares);

        vm.assertEq(BorrowShare.unwrap(targetShare), 9999999999999999999);
    }
}