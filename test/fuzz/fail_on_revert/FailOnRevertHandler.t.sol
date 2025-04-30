
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
import {KSCEngine, AggregatorV3Interface} from "../../../src/KSCEngine.sol";
import {KujenStableCoin} from "../../../src/KujenStableCoin.sol";

/// @title FailOnRevertHandler
/// @author Foued SAIDI - 0xkujen
/// @notice defines the way we call our invariants so we don't waste runs
contract FailOnRevertHandler is Test {
    KSCEngine kscEngine;
    KujenStableCoin ksc;
    MockV3Aggregator ethUSDPriceFeed;
    MockV3Aggregator btcUSDPriceFeed;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(KSCEngine p_kscEngine, KujenStableCoin p_ksc) {
        kscEngine = p_kscEngine;
        ksc = p_ksc;
        address[] memory collateralTokens = kscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        ethUSDPriceFeed = MockV3Aggregator(kscEngine.getCollateralTokenPriceFeed(address(weth)));
        btcUSDPriceFeed = MockV3Aggregator(kscEngine.getCollateralTokenPriceFeed(address(wbtc)));
    }

    function mintAndDepositCollateral(uint256 p_collateralSeed, uint256 p_collateralTokenAmount) public {
        // changed the bound to 1 since this is failOnRevert and it will revert on 0
        p_collateralTokenAmount = bound(p_collateralTokenAmount, 1, MAX_DEPOSIT_SIZE); // set the interval for fuzzed p_collateralTokenAmount
        ERC20Mock collateral = _getCollateralFromSeed(p_collateralSeed); // determine which collateral to use
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, p_collateralTokenAmount); // mint the user some collateral
        collateral.approve(address(kscEngine),p_collateralTokenAmount);
        kscEngine.depositCollateral(address(collateral), p_collateralTokenAmount); // deposit the collateral
        vm.stopPrank();
    }

    function redeemCollateral(uint256 p_collateralSeed, uint256 p_collateralTokenAmount) public {
        p_collateralTokenAmount = bound(p_collateralTokenAmount, 0, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(p_collateralSeed);
        vm.prank(msg.sender);
        kscEngine.redeemCollateral(address(collateral), p_collateralTokenAmount);
    }

    function burnKSC(uint256 p_amountToBurn) public {
        p_amountToBurn = bound(p_amountToBurn, 0, ksc.balanceOf(msg.sender)); // cuz you cant burn more that what you have
        if(p_amountToBurn==0){
            return;
        }
        vm.startPrank(msg.sender);
        ksc.approve(address(kscEngine),p_amountToBurn);
        ksc.burn(p_amountToBurn);
        vm.stopPrank();
    }


    function liquidate(uint256 p_collateralSeed, address p_userToBeLiquidated, uint256 p_debtToCover) public {
        uint256 minHealthFactor = kscEngine.getMinHealthFactor();
        uint256 userHealthFactor = kscEngine.getHealthFactor(p_userToBeLiquidated);
        if (userHealthFactor >= minHealthFactor) {
            return;
        }
        p_debtToCover = bound(p_debtToCover, 1, uint256(type(uint96).max));
        
        ERC20Mock collateral = _getCollateralFromSeed(p_collateralSeed);
        kscEngine.liquidateAssets(address(collateral), p_userToBeLiquidated, p_debtToCover);
    }

    function transferKSC(uint256 p_kscAmountToMint, address p_to) public {
        if (p_to == address(0)) {
            p_to = address(1);
        }
        p_kscAmountToMint = bound(p_kscAmountToMint, 0, ksc.balanceOf(msg.sender)); // cant transfer more than you have
        vm.prank(msg.sender);
        ksc.transfer(p_to, p_kscAmountToMint);
    }

    function _getCollateralFromSeed(uint256 p_collateralSeed) private view returns (ERC20Mock) {
        if (p_collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }

    function updateCollateralPrice(uint128, /* newPrice */ uint256 p_collateralSeed) public {
        int256 intNewPrice = 0;
        ERC20Mock collateral = _getCollateralFromSeed(p_collateralSeed);
        MockV3Aggregator priceFeed = MockV3Aggregator(kscEngine.getCollateralTokenPriceFeed(address(collateral)));

        priceFeed.updateAnswer(intNewPrice);
    }
}
