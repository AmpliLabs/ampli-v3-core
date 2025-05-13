// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IIrm} from "src/interfaces/IIrm.sol";
import {InterestRate} from "src/types/InterestRate.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

contract IrmMock is IIrm {
    uint256 public mockBorrowRate;

    function setBorrowRate(uint256 _mockBorrowRate) public {
        mockBorrowRate = _mockBorrowRate;
    }

    function borrowRate(PoolKey calldata) external view returns (InterestRate) {
        return InterestRate.wrap(mockBorrowRate);
    }
}
