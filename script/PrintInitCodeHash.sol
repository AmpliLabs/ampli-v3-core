/*1. Copy this script to the 'script' directory of your Foundry project.*/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/* 2. Replace 'YourHook' with the name of the hook for which you want to compute the Init Code Hash */
import {Ampli as TargetHook} from "../src/Ampli.sol";

contract PrintInitCodeHash is Script {
    /* 3. Uncomment the PoolManager address corresponding to the network you are using */
    // Mainnet Deployments
    // address constant PM_ADDRESS = 0x000000000004444c5dc75cB358380D2e3dE08A90; // Mainnet: 1
    // address constant PM_ADDRESS = 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3; // Optimism: 10
    address constant PM_ADDRESS = 0x498581fF718922c3f8e6A244956aF099B2652b2b; // Base: 8453
    // address constant PM_ADDRESS = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32; // Arbitrum One: 42161
    // address constant PM_ADDRESS = 0x67366782805870060151383F4BbFF9daB53e5cD6; // Polygon: 137
    // address constant PM_ADDRESS = 0x1631559198A9e474033433b2958daBC135ab6446; // Blast: 81457
    // address constant PM_ADDRESS = 0x0575338e4C17006aE181B47900A84404247CA30f; // Zora: 7777777
    // address constant PM_ADDRESS = 0xb1860D529182ac3BC1F51Fa2ABd56662b7D13f33; // Worldchain: 480
    // address constant PM_ADDRESS = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32; // Ink: 57073
    // address constant PM_ADDRESS = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32; // Soneium: 1868
    // address constant PM_ADDRESS = 0x06380C0e0912312B5150364B9DC4542BA0DbBc85; // Avalanche: 43114
    // address constant PM_ADDRESS = 0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF; // BNB Smart Chain: 56

    // Testnet Deployments
    // address constant PM_ADDRESS = 0x00B036B58a818B1BC34d502D3fE730Db729e62AC; // Unichain Sepolia: 1301
    // address constant PM_ADDRESS = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;  // Sepolia: 11155111
    // address constant PM_ADDRESS = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;  // Base Sepolia: 84532
    // address constant PM_ADDRESS = 0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317;  // Arbitrum Sepolia: 421614

    function run() public pure {
        // Hook constructor arguments
        bytes memory constructorArguments = abi.encode(PM_ADDRESS, 0x22DBB04BB1D47DCa6016284eec5C0FA434b96Bc1);

        // Print Init Code Hash
        bytes memory creationCodeWithConstructorArguments =
            abi.encodePacked(type(TargetHook).creationCode, constructorArguments);
        console.log("Init Code Hash:");
        console.logBytes32(keccak256(creationCodeWithConstructorArguments));
    }
}

/* 5. Run `forge script PrintInitCodeHash` to compute the Init Code Hash for the specified hook */
