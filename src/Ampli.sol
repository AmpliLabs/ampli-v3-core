// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {BaseHook, Hooks, IPoolManager, BeforeSwapDelta, BalanceDelta} from "./BaseHook.sol";
import {IAmpli} from "./interfaces/IAmpli.sol";
import {IIrm} from "./interfaces/IIrm.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {IUnlockCallback} from "./interfaces/callback/IUnlockCallback.sol";
import {PegToken} from "./tokenization/PegToken.sol";
import {Pool} from "./types/Pool.sol";
import {Locker} from "./types/Locker.sol";
import {NonFungibleAssetId} from "./types/NonFungibleAssetId.sol";
import {BorrowShare} from "./types/BorrowShare.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

contract Ampli is IAmpli, BaseHook {
    using StateLibrary for IPoolManager;

    mapping(PoolId id => Pool) internal _pools;

    modifier onlyWhenUnlocked() {
        require(Locker.isUnlocked(), ManagerLocked());
        _;
    }

    //Hooks.Permissions(false, false, true, false, true, false, true, true, false, false, false, false, false, false)
    constructor(IPoolManager manager) BaseHook(manager) {}

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

        address pegToken = address(new PegToken{salt: salt}(underlying, address(this)));
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

    function repay(PoolKey memory key, uint256 positionId, BorrowShare share) external onlyWhenUnlocked {
        PoolId id = key.toId();
        Pool storage pool = _pools[id];

        pool.checkPoolInitialized();
        uint256 repayAsset = pool.repay(key, positionId, share);

        Locker.checkOutItems(id, positionId);

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

        emit WithdrawNonFungibleCollateral(id, positionId, nonFungibleAssetId.nft(), nonFungibleAssetId.tokenId());
    }

    /* LIQUIDATION */

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
    ) external override onlyPoolManager returns (bytes4) {
        if (sender != address(this)) {
            PoolId id = key.toId();
            (, int24 tick,,) = poolManager.getSlot0(id);

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
    ) external override onlyPoolManager returns (bytes4) {
        if (sender != address(this)) {
            PoolId id = key.toId();
            (, int24 tick,,) = poolManager.getSlot0(id);

            if (tick >= params.tickLower && tick < params.tickUpper) {
                _pools[id].accrueInterest(key, false);
            }
        }

        return this.beforeRemoveLiquidity.selector;
    }

    function beforeSwap(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
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
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata /*hookData*/
    ) external override onlyPoolManager returns (bytes4, int128) {
        // TODO: send price to oracle
        // TODO: if price > 1, swap peg token
        return (this.afterSwap.selector, 0);
    }
}
