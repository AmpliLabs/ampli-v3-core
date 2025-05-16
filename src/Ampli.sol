// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Extsload} from "./Extsload.sol";
import {IAmpli} from "./interfaces/IAmpli.sol";
import {IIrm} from "./interfaces/IIrm.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {IPegTokenFactory} from "./interfaces/IPegTokenFactory.sol";
import {IUnlockCallback} from "./interfaces/callback/IUnlockCallback.sol";
import {Pool} from "./types/Pool.sol";
import {Locker} from "./types/Locker.sol";
import {NonFungibleAssetId} from "./types/NonFungibleAssetId.sol";
import {BorrowShare} from "./types/BorrowShare.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks, IPoolManager, BeforeSwapDelta, BalanceDelta} from "v4-core/interfaces/IHooks.sol";

contract Ampli is IAmpli, Extsload {
    error NotPoolManager();

    IPoolManager public immutable poolManager;
    IPegTokenFactory public immutable factory;

    mapping(PoolId id => Pool) internal _pools;

    modifier onlyWhenUnlocked() {
        require(Locker.isUnlocked(), ManagerLocked());
        _;
    }

    //Hooks.Permissions(false, false, true, false, true, false, true, true, false, false, false, false, false, false)
    constructor(IPoolManager _manager, IPegTokenFactory _factory) {
        poolManager = _manager;
        factory = _factory;
    }

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    function unlock(bytes calldata data) external returns (bytes memory result) {
        require(!Locker.isUnlocked(), AlreadyUnlocked());

        Locker.unlock();

        result = IUnlockCallback(msg.sender).unlockCallback(data);

        for (uint256 i = 0; i < Locker.itemsLength(); i++) {
            (PoolId id, uint256 positionId) = Locker.getCheckOutItem(i);
            _pools[id].isHealthy(positionId);
        }
        Locker.lock();
    }

    function initialize(
        address underlying,
        address owner,
        IIrm irm,
        IOracle oracle,
        uint8 feeRatio,
        uint8 ownerFeeRatio,
        bytes32 salt
    ) external {
        require(ownerFeeRatio < 100, InvaildFeeRatio());
        require(feeRatio < 100, InvaildFeeRatio());

        address pegToken = factory.createPegToken(underlying, address(this), salt);
        require(pegToken < underlying, InvaildPegTokenSalt());

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(pegToken),
            currency1: Currency.wrap(underlying),
            fee: 100, // 0.01%
            tickSpacing: 1,
            hooks: IHooks(address(this))
        });

        PoolId id = key.toId();

        _pools[id].initialize(key, owner, irm, oracle, feeRatio, ownerFeeRatio);

        emit Initialize(id, key.currency0, key.currency1, irm, oracle);
        emit SetOwner(id, owner);
        emit SetFee(id, feeRatio, ownerFeeRatio);
    }

    /* POOL MANAGEMENT */
    function setNewOwner(PoolKey memory key, address newOwner) external {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];
        pool.onlyOwner();
        pool.setOwner(newOwner);

        emit SetOwner(id, newOwner);
    }

    function enableFungibleCollateral(PoolKey memory key, address reserve, uint96 lltv) external {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];
        pool.onlyOwner();
        uint256 assetId = pool.enableFungibleCollateral(reserve, lltv);

        emit SetFungibleCollateral(id, assetId, reserve, lltv);
    }

    function updateFungibleCollateral(PoolKey memory key, uint256 fungibleAssetId, uint96 lltv) external {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];
        pool.onlyOwner();
        address fungibleAddress = pool.updateFungibleCollateral(fungibleAssetId, lltv);

        emit SetFungibleCollateral(id, fungibleAssetId, fungibleAddress, lltv);
    }

    function updateNonFungibleCollateral(PoolKey memory key, address reserve, uint256 lltv) external {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];
        pool.onlyOwner();
        pool.updateNonFungibleCollateral(reserve, lltv);

        emit SetNonFungibleCollateral(id, reserve, lltv);
    }

    function updateFeeRatio(PoolKey memory key, uint8 feeRatio, uint8 ownerFeeRatio) external {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];
        pool.onlyOwner();
        pool.updateFeeRatio(feeRatio, ownerFeeRatio);

        emit SetFee(id, feeRatio, ownerFeeRatio);
    }

    /* POSITION MANAGEMENT */

    function updateAuthorization(PoolKey memory key, uint256 positionId, address owner, address authorizedOperator)
        external
    {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];
        pool.updatePositionAuthorization(positionId, owner, authorizedOperator);
    }

    /* SUPPLY MANAGEMENT */

    function supplyFungibleCollateral(PoolKey memory key, uint256 positionId, uint256 fungibleAssetId, uint256 amount)
        external
    {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];

        pool.checkPoolInitialized();
        address fungibleAddress = pool.supplyFungibleCollateral(key, positionId, fungibleAssetId, amount);

        emit SupplyFungibleCollateral(id, positionId, fungibleAddress, amount);
    }

    function supplyNonFungibleCollateral(PoolKey memory key, uint256 positionId, NonFungibleAssetId nonFungibleAssetId)
        external
    {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];

        pool.checkPoolInitialized();
        pool.supplyNonFungibleCollateral(key, positionId, nonFungibleAssetId);

        emit SuppluNonFungibleCollateral(id, positionId, nonFungibleAssetId.nft(), nonFungibleAssetId.tokenId());
    }

    /* BORROW MANAGEMENT */

    function borrow(PoolKey memory key, uint256 positionId, address receiver, BorrowShare share)
        external
        onlyWhenUnlocked
    {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];

        pool.checkPoolInitialized();
        uint256 borrowAsset = pool.borrow(key, receiver, positionId, share);

        Locker.checkOutItems(id, positionId);

        emit Borrow(id, positionId, receiver, borrowAsset, share);
    }

    function repay(PoolKey memory key, uint256 positionId, BorrowShare share) external {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];

        pool.checkPoolInitialized();
        uint256 repayAsset = pool.repay(key, positionId, share);

        emit Repay(id, positionId, repayAsset, share);
    }

    /* WITHDRAW MANAGEMENT */

    function withdrawFungibleCollateral(PoolKey memory key, uint256 positionId, uint256 fungibleAssetId, uint256 amount)
        external
        onlyWhenUnlocked
    {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];

        pool.checkPoolInitialized();
        address fungibleAddress = pool.withdrawFungibleCollateral(key, positionId, fungibleAssetId, amount);
        Locker.checkOutItems(id, positionId);

        emit WithdrawFungibleCollateral(id, positionId, fungibleAddress, amount);
    }

    function withdrawNonFungibleCollateral(
        PoolKey memory key,
        uint256 positionId,
        NonFungibleAssetId nonFungibleAssetId
    ) external onlyWhenUnlocked {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];

        pool.checkPoolInitialized();
        pool.withdrawNonFungibleCollateral(key, positionId, nonFungibleAssetId);
        Locker.checkOutItems(id, positionId);

        emit WithdrawNonFungibleCollateral(id, positionId, nonFungibleAssetId.nft(), nonFungibleAssetId.tokenId());
    }

    /* LIQUIDATION */

    // TODO: Liquidate in unlock with checkout
    function liquidate(PoolKey memory key, uint256 positionId) external {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];

        pool.checkPoolInitialized();
        (uint256 repaidAsset, int256 bedDebtAsset) = pool.liquidate(key, positionId);

        emit Liquidate(id, positionId, repaidAsset, uint256(-bedDebtAsset));
    }

    /* HOOKS */
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata /*hookData*/
    ) external onlyPoolManager returns (bytes4) {
        if (sender != address(this)) {
            PoolId id = key.toId();
            (, int24 tick,,) = getSlot0(poolManager, id);

            if (tick >= params.tickLower && tick < params.tickUpper) {
                _pools[id].accrueInterest(key, true);
            }
        }

        return this.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata /*hookData*/
    ) external onlyPoolManager returns (bytes4) {
        if (sender != address(this)) {
            PoolId id = key.toId();
            (, int24 tick,,) = getSlot0(poolManager, id);

            if (tick >= params.tickLower && tick < params.tickUpper) {
                _pools[id].accrueInterest(key, false);
            }
        }

        return this.beforeRemoveLiquidity.selector;
    }

    function beforeSwap(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (sender != address(this)) {
            PoolId id = key.toId();
            _pools[id].accrueInterest(key, true);
        }

        return (this.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }

    function afterSwap(
        address, /*sender*/
        PoolKey calldata, /*key*/
        IPoolManager.SwapParams calldata, /*params*/
        BalanceDelta, /*delta*/
        bytes calldata /*hookData*/
    ) external view onlyPoolManager returns (bytes4, int128) {
        // TODO: send price to oracle
        // TODO: if price > 1, swap peg token
        return (this.afterSwap.selector, 0);
    }

    /* POOL MANAGER SLOT */
    function _getPoolStateSlot(PoolId poolId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(PoolId.unwrap(poolId), bytes32(uint256(6))));
    }

    function getSlot0(IPoolManager manager, PoolId poolId)
        internal
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)
    {
        // slot key of Pool.State value: `pools[poolId]`
        bytes32 stateSlot = _getPoolStateSlot(poolId);

        bytes32 data = manager.extsload(stateSlot);

        //   24 bits  |24bits|24bits      |24 bits|160 bits
        // 0x000000   |000bb8|000000      |ffff75 |0000000000000000fe3aa841ba359daa0ea9eff7
        // ---------- | fee  |protocolfee | tick  | sqrtPriceX96
        assembly ("memory-safe") {
            // bottom 160 bits of data
            sqrtPriceX96 := and(data, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            // next 24 bits of data
            tick := signextend(2, shr(160, data))
            // next 24 bits of data
            protocolFee := and(shr(184, data), 0xFFFFFF)
            // last 24 bits of data
            lpFee := and(shr(208, data), 0xFFFFFF)
        }
    }
}
