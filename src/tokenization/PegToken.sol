// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IPegToken} from "../interfaces/IPegToken.sol";
import {IERC20} from "../interfaces/IERC20.sol";

/// @notice Standard fungible token (https://eips.ethereum.org/EIPS/eip-20).
contract PegToken is IPegToken {
    error InvaildManager();

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    address public immutable manager;
    address public immutable underlyingAsset;

    uint256 public totalSupply;

    mapping(address holder => uint256) public balanceOf;
    mapping(address holder => mapping(address spender => uint256)) public allowance;

    constructor(address _underlyingAsset, address _manager) {
        (manager, underlyingAsset) = (_manager, _underlyingAsset);

        name = string(concat(bytes("Ampli Peg "), bytes(IERC20(underlyingAsset).name())));
        symbol = string(concat(bytes("p"), bytes(IERC20(underlyingAsset).symbol())));
        decimals = IERC20(underlyingAsset).decimals();
    }

    modifier onlyManager() {
        require(msg.sender == manager, InvaildManager());
        _;
    }

    function approve(address to, uint256 amount) public returns (bool) {
        allowance[msg.sender][to] = amount;
        emit Approval(msg.sender, to, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) public onlyManager {
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) public onlyManager {
        balanceOf[from] -= amount;
        unchecked {
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    /// @dev Returns a concatenated bytes of `a` and `b`.
    /// Cheaper than `bytes.concat()` and does not de-align the free memory pointer.
    function concat(bytes memory a, bytes memory b) internal pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let w := not(0x1f)
            let aLen := mload(a)
            // Copy `a` one word at a time, backwards.
            for { let o := and(add(aLen, 0x20), w) } 1 {} {
                mstore(add(result, o), mload(add(a, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                if iszero(o) { break }
            }
            let bLen := mload(b)
            let output := add(result, aLen)
            // Copy `b` one word at a time, backwards.
            for { let o := and(add(bLen, 0x20), w) } 1 {} {
                mstore(add(output, o), mload(add(b, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                if iszero(o) { break }
            }
            let totalLen := add(aLen, bLen)
            let last := add(add(result, 0x20), totalLen)
            mstore(last, 0) // Zeroize the slot after the bytes.
            mstore(result, totalLen) // Store the length.
            mstore(0x40, add(last, 0x20)) // Allocate memory.
        }
    }
}
