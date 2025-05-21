// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Ampli} from "src/Ampli.sol";
import {PegTokenFactory} from "src/PegTokenFactory.sol";
import {IPegTokenFactory} from "src/interfaces/IPegTokenFactory.sol";

contract DeployPegToken is Script {
    bytes32 constant salt = hex"00";

    function run() public returns (PegTokenFactory factory) {
        vm.createSelectFork("Base");
        vm.startBroadcast(vm.envUint("DEPLOY_PRIVATE"));
        factory = new PegTokenFactory{salt: salt}();
        vm.stopBroadcast();
    }
}

contract DeployHook is Script {
    // Ampli public ampli;
    IPoolManager constant PM_ADDRESS = IPoolManager(0x498581fF718922c3f8e6A244956aF099B2652b2b);
    bytes32 constant salt = 0xeda74532bf55ade24954b3c5a283192477d5b97ddaa327b5089ec44d766543fa;
    address constant factory = address(0xB2Cf8DCCfE32B357fAe9AE2C6bCD35FA43E03d6c);

    function run() public returns (Ampli ampli) {
        // vm.createSelectFork("Base");
        vm.startBroadcast(vm.envUint("DEPLOY_PRIVATE"));
        ampli = new Ampli{salt: salt}(PM_ADDRESS, IPegTokenFactory(factory));
        vm.stopBroadcast();
        // return ampli;
    }
}
