// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IExtsload} from "./IExtsload.sol";
import {IExttload} from "./IExttload.sol";
import {NonFungibleAssetId} from "../types/NonFungibleAssetId.sol";
import {BorrowShare} from "../types/BorrowShare.sol";
import {IIrm} from "../interfaces/IIrm.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";

interface IAmpli is IExtsload, IExttload {
    error NotPoolManager();
    error ManagerLocked();
    error AlreadyUnlocked();
    error InvaildOwner();
    error NotOwner();
    error InvaildFeeRatio();
    error InvaildPegTokenSalt();
    error MustClearExactPositiveDelta();
    error NonzeroNativeValue();
    error CurrencyNotSettled();

    event Initialize(
        PoolId indexed id, Currency indexed pegToken, Currency indexed underlying, IIrm irm, IOracle oracle
    );
    event SupplyFungibleCollateral(
        PoolId indexed id, uint256 indexed positionId, Currency indexed asset, uint256 amount
    );
    event SuppluNonFungibleCollateral(
        PoolId indexed id, uint256 indexed positionId, address indexed asset, uint256 tokenId
    );
    event WithdrawFungibleCollateral(
        PoolId indexed id, uint256 indexed positionId, Currency indexed asset, uint256 amount
    );
    event WithdrawNonFungibleCollateral(
        PoolId indexed id, uint256 indexed positionId, address indexed asset, uint256 tokenId
    );
    event Borrow(PoolId indexed id, uint256 indexed positionId, uint256 amount, BorrowShare share);
    event Repay(PoolId indexed id, uint256 indexed positionId, uint256 assets, BorrowShare share);
    event Liquidate(PoolId indexed id, uint256 indexed positionId, uint256 repaidAsset, uint256 bedDebtAsset);
    event SetOwner(PoolId indexed id, address indexed newOwner);
    event SetFee(PoolId indexed id, uint8 feeRatio, uint8 ownerFeeRatio);
    event SetFungibleCollateral(PoolId indexed id, uint256 indexed assetId, Currency indexed asset, uint256 lltv);
    event SetNonFungibleCollateral(PoolId indexed id, address indexed asset, uint256 lltv);

    function unlock(bytes calldata data) external returns (bytes memory result);
    function initialize(
        address underlying,
        address owner,
        IIrm irm,
        IOracle oracle,
        uint8 feeRatio,
        uint8 ownerFeeRatio,
        bytes32 salt
    ) external returns (address);
    function updateAuthorization(PoolKey memory key, uint256 positionId, address owner, address authorizedOperator)
        external;
    function supplyFungibleCollateral(PoolKey memory key, uint256 positionId, uint256 fungibleAssetId, uint256 amount)
        external;
    function supplyNonFungibleCollateral(PoolKey memory key, uint256 positionId, NonFungibleAssetId nonFungibleAssetId)
        external;
    function withdrawFungibleCollateral(PoolKey memory key, uint256 positionId, uint256 fungibleAssetId, uint256 amount)
        external;
    function borrow(PoolKey memory key, uint256 positionId, BorrowShare share) external;

    function sync(Currency currency) external;
    function take(Currency currency, address to, uint256 amount) external;
    function settle() external payable returns (uint256 paid);
    function settleFor(address recipient) external payable returns (uint256 paid);
    function clear(Currency currency, uint256 amount) external;
}
