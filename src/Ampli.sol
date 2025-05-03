// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IAmpli} from "./interfaces/IAmpli.sol";
import {PositionId} from "./types/PositionId.sol";
import {NonFungibleAssetId} from "./types/NonFungibleAssetId.sol";
import {Position} from "./types/Position.sol";
import {SafeTransferLibrary} from "./libraries/SafeTransfer.sol";

contract Ampli is IAmpli {
    using SafeTransferLibrary for address;

    address public owner;

    uint8 internal _reservesCount;

    mapping(uint256 => address) internal _reservesList;
    mapping(uint256 => AssetParams) internal _assetParams;
    mapping(PositionId => Position) internal _positions;

    mapping(address nft => bool isCollateral) public isNFTCollateral;

    constructor(address newOwner) {
        require(newOwner != address(0), InvaildOwner());

        owner = newOwner;

        emit SetOwner(owner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, NotOwner());
        _;
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;

        emit SetOwner(newOwner);
    }

    function enableFungibleCollateral(address reserve, AssetParams calldata asset) external onlyOwner {
        _reservesList[_reservesCount] = reserve;
        _assetParams[_reservesCount] = asset;

        _reservesCount += 1;

        emit SetAssetParams(_reservesCount, reserve, asset.oracle, asset.lltv);
    }

    function enableNonFungibleCollateral(address reserve) external onlyOwner {
        isNFTCollateral[reserve] = true;
    }

    /* SUPPLY MANAGEMENT */

    function supplyFungibleCollateral(PositionId positionId, uint256 fungibleAssetId, uint256 amount) external {
        require(_reservesList[fungibleAssetId] != address(0), InvaildFungibleAsset());
        Position storage position = _positions[positionId];
        address fungibleAddress = _reservesList[fungibleAssetId];

        position.addFungible(fungibleAssetId, amount);

        emit SupplyFungibleCollateral(positionId, msg.sender, fungibleAddress, amount);

        fungibleAddress.safeTransferFrom(msg.sender, address(this), amount);
    }

    function supplyNonFungibleCollateral(PositionId positionId, NonFungibleAssetId nonFungibleAssetId) external {
        Position storage position = _positions[positionId];
        address nftAddress = nonFungibleAssetId.nft();
        uint256 tokenId = nonFungibleAssetId.tokenId();

        require(isNFTCollateral[nftAddress], InvaildNonFungibleAsset());

        position.addNonFungible(nonFungibleAssetId);

        emit SuppluNonFungibleCollateral(positionId, msg.sender, nftAddress, tokenId);

        nftAddress.safeTransferFrom(msg.sender, address(this), tokenId);
    }
}
