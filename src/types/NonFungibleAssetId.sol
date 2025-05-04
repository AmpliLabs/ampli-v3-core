// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/// @dev Layout: address nft | uint96 tokenId
type NonFungibleAssetId is bytes32;

using NonFungibleAssetIdLibrary for NonFungibleAssetId global;

library NonFungibleAssetIdLibrary {
    uint96 private constant MASK_96_BITS = 0xFFFFFFFFFFFFFFFFFFFFFFFF;

    // #### GETTERS ####
    function nft(NonFungibleAssetId self) internal pure returns (address _nft) {
        assembly ("memory-safe") {
            _nft := shr(96, self)
        }
    }

    function tokenId(NonFungibleAssetId self) internal pure returns (uint96 _tokenId) {
        assembly ("memory-safe") {
            _tokenId := and(self, MASK_96_BITS)
        }
    }

    // #### SETTERS ####
    function toNonFungibleAssetId(address _nft, uint96 _tokenId) internal pure returns (NonFungibleAssetId id) {
        assembly ("memory-safe") {
            id := or(shl(96, _nft), and(_tokenId, MASK_96_BITS))
        }
    }
}
