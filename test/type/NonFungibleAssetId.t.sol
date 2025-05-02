// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {NonFungibleAssetId, NonFungibleAssetIdLibrary} from "../../src/types/NonFungibleAssetId.sol";

contract NonFungibleAssetIdTest is Test {
    function test_fuzz_nftId_pack_unpack(address nft, uint96 tokenId) public pure {
        NonFungibleAssetId nftId = NonFungibleAssetIdLibrary.toNonFungibleAssetId(nft, tokenId);

        assertEq(nftId.nft(), nft);
        assertEq(nftId.tokenId(), tokenId);
    }
}
