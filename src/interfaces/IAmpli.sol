// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {NonFungibleAssetId} from "../types/NonFungibleAssetId.sol";
import {BorrowShare} from "../types/BorrowShare.sol";
import {IIrm} from "../interfaces/IIrm.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";

interface IAmpli {
    error ManagerLocked();
    error AlreadyUnlocked();
    error InvaildOwner();
    error NotOwner();
    error InvaildFeeRatio();
    error InvaildPegTokenSalt();

    event Initialize(
        PoolId indexed id, Currency indexed pegToken, Currency indexed underlying, IIrm irm, IOracle oracle
    );
    event SupplyFungibleCollateral(
        PoolId indexed id, uint256 indexed positionId, address indexed asset, uint256 amount
    );
    event SuppluNonFungibleCollateral(
        PoolId indexed id, uint256 indexed positionId, address indexed asset, uint256 tokenId
    );
    event WithdrawFungibleCollateral(
        PoolId indexed id, uint256 indexed positionId, address indexed asset, uint256 amount
    );
    event WithdrawNonFungibleCollateral(
        PoolId indexed id, uint256 indexed positionId, address indexed asset, uint256 tokenId
    );
    event Borrow(
        PoolId indexed id, uint256 indexed positionId, address indexed receiver, uint256 assets, BorrowShare share
    );
    event Repay(PoolId indexed id, uint256 indexed positionId, uint256 assets, BorrowShare share);
    event Liquidate(PoolId indexed id, uint256 indexed positionId, uint256 repaidAsset, uint256 bedDebtAsset);
    event SetOwner(PoolId indexed id, address indexed newOwner);
    event SetFee(PoolId indexed id, uint8 feeRatio, uint8 ownerFeeRatio);
    event SetFungibleCollateral(uint256 indexed id, address indexed asset, uint256 lltv);
    event SetNonFungibleCollateral(address indexed asset, uint256 lltv);
}
