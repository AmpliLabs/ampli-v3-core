// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

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

contract Ampli is IAmpli {
    mapping(PoolId id => Pool) internal _pools;

    modifier onlyWhenUnlocked() {
        require(Locker.isUnlocked(), ManagerLocked());
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

        address pegToken = address(new PegToken{salt: salt}(underlying, address(this)));
        require(underlying < pegToken, InvaildPegTokenSalt());

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

    /* SUPPLY MANAGEMENT */

    function supplyFungibleCollateral(PoolKey memory key, uint256 positionId, uint256 fungibleAssetId, uint256 amount)
        external
        onlyWhenUnlocked
    {
        PoolId id = key.toId();
        address fungibleAddress = _pools[id].supplyFungibleCollateral(key, positionId, fungibleAssetId, amount);
        emit SupplyFungibleCollateral(id, positionId, fungibleAddress, amount);
    }

    function supplyNonFungibleCollateral(PoolKey memory key, uint256 positionId, NonFungibleAssetId nonFungibleAssetId)
        external
        onlyWhenUnlocked
    {
        PoolId id = key.toId();
        _pools[id].supplyNonFungibleCollateral(key, positionId, nonFungibleAssetId);
        emit SuppluNonFungibleCollateral(id, positionId, nonFungibleAssetId.nft(), nonFungibleAssetId.tokenId());
    }

    /* BORROW MANAGEMENT */

    function borrow(PoolKey memory key, uint256 positionId, address receiver, BorrowShare share)
        external
        onlyWhenUnlocked
    {
        PoolId id = key.toId();
        uint256 borrowAsset = _pools[id].borrow(key, receiver, positionId, share);

        // TODO: checkout in lock

        emit Borrow(id, positionId, receiver, borrowAsset, share);
    }

    function repay(PoolKey memory key, uint256 positionId, BorrowShare share) external onlyWhenUnlocked {
        PoolId id = key.toId();
        uint256 repayAsset = _pools[id].repay(key, positionId, share);

        // TODO: checkout in lock

        emit Repay(id, positionId, repayAsset, share);
    }

    /* WITHDRAW MANAGEMENT */

    function withdrawFungibleCollateral(PoolKey memory key, uint256 positionId, uint256 fungibleAssetId, uint256 amount)
        external
        onlyWhenUnlocked
    {
        PoolId id = key.toId();
        address fungibleAddress = _pools[id].withdrawFungibleCollateral(key, positionId, fungibleAssetId, amount);
        emit WithdrawFungibleCollateral(id, positionId, fungibleAddress, amount);
    }

    function withdrawNonFungibleCollateral(
        PoolKey memory key,
        uint256 positionId,
        NonFungibleAssetId nonFungibleAssetId
    ) external onlyWhenUnlocked {
        PoolId id = key.toId();
        _pools[id].withdrawNonFungibleCollateral(key, positionId, nonFungibleAssetId);
        emit WithdrawNonFungibleCollateral(id, positionId, nonFungibleAssetId.nft(), nonFungibleAssetId.tokenId());
    }

    /* LIQUIDATION */

    function liquidate(PoolKey memory key, uint256 positionId) external {
        PoolId id = key.toId();
        (uint256 repaidAsset, int256 bedDebtAsset) = _pools[id].liquidate(key, positionId);

        emit Liquidate(id, positionId, repaidAsset, uint256(-bedDebtAsset));
    }
}
