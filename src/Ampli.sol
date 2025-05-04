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
    mapping(PositionId => Position) internal _positions;

    mapping(address nft => bool isCollateral) public isNFTCollateral;
    mapping(uint256 fungibleAssetId => uint256 lltv) public fungibleAssetParams;
    mapping(address nonFungibleAsset => uint256 lltv) public nonFungibleAssetParams;

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

    function enableFungibleCollateral(address reserve, uint256 lltv) external onlyOwner {
        fungibleAssetParams[_reservesCount] = lltv;

        _reservesList[_reservesCount] = reserve;
        _reservesCount += 1;

        emit SetFungibleCollateral(_reservesCount, reserve, lltv);
    }

    function enableNonFungibleCollateral(address reserve, uint256 lltv) external onlyOwner {
        nonFungibleAssetParams[reserve] = lltv;
        isNFTCollateral[reserve] = true;

        emit SetNonFungibleCollateral(reserve, lltv);
    }

    /* SUPPLY MANAGEMENT */

    function supplyFungibleCollateral(PositionId positionId, uint256 fungibleAssetId, uint256 amount) external {
        require(_reservesList[fungibleAssetId] != address(0), InvaildFungibleAsset());
        Position storage position = _positions[positionId];
        address fungibleAddress = _reservesList[fungibleAssetId];

        // TODO: accrue interest

        position.addFungible(fungibleAssetId, amount);

        emit SupplyFungibleCollateral(positionId, msg.sender, fungibleAddress, amount);

        fungibleAddress.safeTransferFrom(msg.sender, address(this), amount);

        // TODO: checkout position
    }

    function supplyNonFungibleCollateral(PositionId positionId, NonFungibleAssetId nonFungibleAssetId) external {
        Position storage position = _positions[positionId];
        address nftAddress = nonFungibleAssetId.nft();
        uint256 tokenId = nonFungibleAssetId.tokenId();

        require(isNFTCollateral[nftAddress], InvaildNonFungibleAsset());

        // TODO: accrue interest

        position.addNonFungible(nonFungibleAssetId);

        emit SuppluNonFungibleCollateral(positionId, msg.sender, nftAddress, tokenId);

        nftAddress.safeTransferFrom(msg.sender, address(this), tokenId);

        // TODO: checkout position
    }
}
