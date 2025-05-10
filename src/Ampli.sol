// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IAmpli} from "./interfaces/IAmpli.sol";
import {IIrm} from "./interfaces/IIrm.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {PegToken} from "./tokenization/PegToken.sol";
import {Pool} from "./types/Pool.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

contract Ampli is IAmpli {
    mapping(PoolId id => Pool) internal _pools;

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
}
