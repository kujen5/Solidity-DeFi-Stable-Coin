// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ContinueOnRevertHandler} from "./ContinueOnRevertHandler.t.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {KSCEngine} from "../../../src/KSCEngine.sol";
import {KujenStableCoin} from "../../../src/KujenStableCoin.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {DeployKSC} from "../../../script/DeployKSC.s.sol";

/**
 * Invariants for this test suite:
 * - protocol must always be overcollateralized
 * - users cant mint KSC with a bad health factor
 * - can only liquidate a user if they have a bad health factor
 */
contract ContinueOnRevertInvariant is StdInvariant, Test {
    KSCEngine public kscEngine;
    KujenStableCoin public ksc;
    HelperConfig public helperConfig;
    address public ethUSDPriceFeed;
    address public btcUSDPriceFeed;
    address public weth;
    address public wbtc;
    uint256 collateralTokenAmount = 10 ether;
    uint256 kscAmountToMint = 100 ether;
    address public user = makeAddr("KUJEN");
    uint256 public constant INITIAL_USER_BALANCE = 10 ether;
    uint256 public constant MINIMUM_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    address public liquidator = makeAddr("LIQUIDATOR");
    uint256 public collateralToCover = 20 ether;
    ContinueOnRevertHandler public handler;

    function setUp() external {
        DeployKSC deployer = new DeployKSC();
        (ksc, kscEngine, helperConfig) = deployer.run();
        (ethUSDPriceFeed, btcUSDPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
        handler = new ContinueOnRevertHandler(kscEngine, ksc);
        targetContract(address(handler)); // we define our target contract for invariant tests
    }

    function invariant_proocolMustHaveMoreValueThanTotalSupplyDollars() public view {
        uint256 totalSupply = ksc.totalSupply();
        uint256 wethDeposited = ERC20Mock(weth).balanceOf(address(kscEngine));
        uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(kscEngine));
        uint256 wethValue = kscEngine.getUSDConversionRate(weth, wethDeposited);
        uint256 wbtcValue = kscEngine.getUSDConversionRate(wbtc, wbtcDeposited);
        console.log("Total Supply: %s", totalSupply);
        console.log("wethValue: %s", wethValue);
        console.log("wbtcValue: %s", wbtcValue);
        assert(wethValue + wbtcValue >= totalSupply);
        //assertGt(wethValue+wbtcValue, totalSupply);
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
