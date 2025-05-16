// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Ampli} from "src/Ampli.sol";
import {PegTokenFactory} from "src/PegTokenFactory.sol";
import {IPegTokenFactory} from "src/interfaces/IPegTokenFactory.sol";

contract DeployPegToken is Script {
    function run() public returns (PegTokenFactory factory) {
        vm.createSelectFork("Base");
        vm.startBroadcast(vm.envUint("DEPLOY_PRIVATE"));
        factory = new PegTokenFactory();
        vm.stopBroadcast();
    }
}

contract DeployHook is Script {
    // Ampli public ampli;
    IPoolManager constant PM_ADDRESS = IPoolManager(0x498581fF718922c3f8e6A244956aF099B2652b2b);
    bytes32 constant salt = 0xc21528bef3c455520a5a08e091f63d93721e87eee729bcfd93042355ee21ea99;
    address constant factory = address(0x22DBB04BB1D47DCa6016284eec5C0FA434b96Bc1);

    function run() public returns (Ampli ampli) {
        vm.createSelectFork("Base");
        vm.startBroadcast(vm.envUint("DEPLOY_PRIVATE"));
        ampli = new Ampli{salt: salt}(PM_ADDRESS, IPegTokenFactory(factory));
        vm.stopBroadcast();
        // return ampli;
    }
}
