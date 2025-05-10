// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {NonFungibleAssetId} from "../types/NonFungibleAssetId.sol";
import {IIrm} from "../interfaces/IIrm.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";

interface IAmpli {
    error InvaildOwner();
    error NotOwner();
    error InvaildFeeRatio();
    error InvaildPegTokenSalt();

    event Initialize(
        PoolId indexed id, Currency indexed pegToken, Currency indexed underlying, IIrm irm, IOracle oracle
    );
    event SetOwner(PoolId indexed id, address indexed newOwner);
    event SetFee(PoolId indexed id, uint8 feeRatio, uint8 ownerFeeRatio);

    event SetFungibleCollateral(uint256 indexed id, address indexed asset, uint256 lltv);
    event SetNonFungibleCollateral(address indexed asset, uint256 lltv);

    event SupplyFungibleCollateral(uint256 indexed id, address indexed caller, address indexed asset, uint256 amount);
    event SuppluNonFungibleCollateral(
        uint256 indexed id, address indexed caller, address indexed asset, uint256 tokenId
    );
}
