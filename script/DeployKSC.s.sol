// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {HelperConfig} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";
import {KSCEngine} from "../src/KSCEngine.sol";
import {KujenStableCoin} from "../src/KujenStableCoin.sol";

contract DeployKSC is Script{
    address[] tokenAddresses;
    address[] priceFeedAddresses;
    function run() external returns (KujenStableCoin,KSCEngine,HelperConfig) {
        HelperConfig helperConfig=new HelperConfig();
        (address wethUsdPriceFeed,address wbtcUsdPriceFeed,address weth,address wbtc,uint256 deployerKey)=helperConfig.activeNetworkConfig();
        tokenAddresses=[weth,wbtc];
        priceFeedAddresses=[wethUsdPriceFeed,wbtcUsdPriceFeed];
        vm.startBroadcast(deployerKey);
        KujenStableCoin ksc=new KujenStableCoin();
        KSCEngine kscEngine=new KSCEngine(tokenAddresses,priceFeedAddresses,address(ksc));
        ksc.transferOwnership(address(kscEngine));
        vm.stopBroadcast();
        return (ksc, kscEngine,helperConfig);
    }
}