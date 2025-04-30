// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {KSCEngine} from "../../src/KSCEngine.sol";
import {DeployKSC} from "../../script/DeployKSC.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockMoreDebtKSC} from "../mocks/MockMoreDebtKSC.sol";
import {MockFailedMintKSC} from "../mocks/MockFailedMintKSC.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {KujenStableCoin} from "../../src/KujenStableCoin.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract KSCEngineTest is Test {
    event CollateralRedeemed(
        address indexed fromAddress,
        address indexed toAddress,
        address collateralTokenAddress,
        uint256 collateralAmountToRedeem
    );

    KSCEngine public kscEngine;
    KujenStableCoin public ksc;
    HelperConfig public helperConfig;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;
    uint256 collateralTokenAmount = 10 ether;
    uint256 kscAmountToMint = 100 ether;
    address public user = makeAddr("KUJEN");
    uint256 public constant INITIAL_USER_BALANCE = 10 ether;
    uint256 public constant MINIMUM_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    address public liquidator = makeAddr("LIQUIDATOR");
    uint256 public collateralToCover = 20 ether;
    address[] public collateralTokensAddresses;
    address[] public collateralTokensPriceFeedAddresses;

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(kscEngine), collateralTokenAmount); // the user approves the kscEngine to spend collateralTokenAmount on his behalf
        kscEngine.depositCollateral(weth, collateralTokenAmount); // now kscEngine will deposit weth collateral on behalf of user(take money from his wallet)
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMintedKSC() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(kscEngine), collateralTokenAmount);
        kscEngine.depositCollateralAndMintKSC(weth, collateralTokenAmount, kscAmountToMint);
        vm.stopPrank();
        _;
    }

    modifier liquidated() {
        vm.startPrank(user);
        // first initiate a weth mock, deposit collateral and mint KSC
        ERC20Mock(weth).approve(address(kscEngine), collateralTokenAmount);
        kscEngine.depositCollateralAndMintKSC(weth, collateralTokenAmount, kscAmountToMint);
        vm.stopPrank();
        // Now update the ethereum price on the priceFeed (crash ethereum price)
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18 (lol)
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        //now calculate the user healthfactor (since the user approved kscEngine to act on his behalf)
        uint256 userHealthFactor = kscEngine.getHealthFactor(user);

        // set up liquidator and give him some WETH
        ERC20Mock(weth).mint(liquidator, collateralToCover);
        vm.startPrank(liquidator);
        // liquidator approves kscEngine to do stuff on his behalf
        ERC20Mock(weth).approve(address(kscEngine), collateralToCover);
        kscEngine.depositCollateralAndMintKSC(weth, collateralToCover, kscAmountToMint);
        ksc.approve(address(kscEngine), kscAmountToMint);
        // now simply liquidator liquidates the user by covering his whole debt
        kscEngine.liquidateAssets(weth, user, kscAmountToMint); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function setUp() external {
        DeployKSC deployer = new DeployKSC();
        (ksc, kscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        if (block.chainid == 31337) {
            vm.deal(user, INITIAL_USER_BALANCE);
        }
        ERC20Mock(weth).mint(user, INITIAL_USER_BALANCE); // we can do this because "weth" already points to a declared ERC20Mock
        ERC20Mock(wbtc).mint(user, INITIAL_USER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevertsIfCollateralTokenAddressAndCollateralTokenPriceFeedDoNotMatchInLength() public {
        collateralTokensPriceFeedAddresses.push(ethUsdPriceFeed);
        collateralTokensPriceFeedAddresses.push(btcUsdPriceFeed);
        collateralTokensAddresses.push(weth);
        vm.expectRevert(KSCEngine.KSCEngine__collateralTokenAddressesAndPriceFeedsAmountDoNotMatch.selector);
        new KSCEngine(collateralTokensAddresses, collateralTokensPriceFeedAddresses, address(ksc)); // we test with a new instance of KSCEngine because the revert exists in the constructor
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevertIfCollateralValueIsEqualToZero() public depositedCollateral {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(kscEngine), collateralTokenAmount);
        vm.expectRevert(KSCEngine.KSCEngine__AmountIsEqualToZeroYouNeedMore.selector);
        kscEngine.depositCollateral(address(weth), 0);
        vm.stopPrank();
    }

    function testRevertIfTokenIsNotOnTheAllowedCollateralTokensList() public {
        ERC20Mock testRandomToken = new ERC20Mock("TEST", "TEST", msg.sender, INITIAL_USER_BALANCE);
        vm.startPrank(user);
        vm.expectRevert(KSCEngine.KSCEngine__TokenIsNotAllowed.selector);
        kscEngine.depositCollateral(address(testRandomToken), collateralTokenAmount); //we don't need to approve the kscEngine to spend the user's funds, because they transaction will fail and revert before even reaching the transferFrom function call

        vm.stopPrank();
    }

    function testOracleReturnsCorrectUSDValueForToken() public view {
        uint256 ethereumAmount = 10e18;
        // we also that 1ETH=2000USD (we set it in our HelperConfig)
        uint256 usdValue = kscEngine.getUSDConversionRate(weth, ethereumAmount);
        uint256 expectedUSDValue = 20000e18;
        assertEq(usdValue, expectedUSDValue);
    }

    function testGetCorrectCollateralTokenAmountFromUSD() public view {
        uint256 usdAmount = 1000e18; //or 1000 ether
        uint256 collateralAmount = kscEngine.getAccountCollateralTokenAmountFromUsd(weth, usdAmount);
        uint256 expectedCollateralAmount = 0.5 ether;
        assertEq(collateralAmount, expectedCollateralAmount);
    }

    ///@notice this test needs its own setup because we're working on a mocked token (a normal ERC20 wouldnt fail at transfer)
    function testRevertIfTransferFails() public {
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransfer mockDecentralizedStableCoin = new MockFailedTransfer();
        collateralTokensAddresses = [address(mockDecentralizedStableCoin)];
        collateralTokensPriceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        KSCEngine mockDecentralizedStableCoinEngine = new KSCEngine(
            collateralTokensAddresses, collateralTokensPriceFeedAddresses, address(mockDecentralizedStableCoin)
        );
        mockDecentralizedStableCoin.mint(user, collateralTokenAmount);
        vm.startPrank(user);
        ERC20Mock(address(mockDecentralizedStableCoin)).approve(
            address(mockDecentralizedStableCoinEngine), collateralTokenAmount
        );
        mockDecentralizedStableCoinEngine.depositCollateral(address(mockDecentralizedStableCoin), collateralTokenAmount);
        vm.expectRevert(KSCEngine.KSCEngine__TransferFailed.selector);
        mockDecentralizedStableCoinEngine.redeemCollateral(address(mockDecentralizedStableCoin), collateralTokenAmount);
        vm.stopPrank();
    }

    function testRevertIfTransferFromFails() public {
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockDecentralizedStableCoin = new MockFailedTransferFrom();
        collateralTokensAddresses = [address(mockDecentralizedStableCoin)];
        collateralTokensPriceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        KSCEngine mockDecentralizedStableCoinEngine = new KSCEngine(
            collateralTokensAddresses, collateralTokensPriceFeedAddresses, address(mockDecentralizedStableCoin)
        );
        mockDecentralizedStableCoin.mint(user, collateralTokenAmount);
        vm.startPrank(user);
        ERC20Mock(address(mockDecentralizedStableCoin)).approve(
            address(mockDecentralizedStableCoinEngine), collateralTokenAmount
        );
        vm.expectRevert(KSCEngine.KSCEngine__TransferFailed.selector);
        mockDecentralizedStableCoinEngine.depositCollateral(address(mockDecentralizedStableCoin), collateralTokenAmount);
        vm.stopPrank();
    }

    function testUserCanDepositCollateralWithoutHavingToMintKSC() public depositedCollateral {
        (uint256 totalKSCMintedByUser, uint256 collateralValueInUSD) = kscEngine.getAccountInfo(user);
        assertEq(totalKSCMintedByUser, 0);
        assertEq(collateralValueInUSD, kscEngine.getUSDConversionRate(weth, collateralTokenAmount));
    }

    function testRevertIfMintedKSCBreaksTheHealthFactor() public {
        // determine ksc amount to mint, approve kscEngine to spend on our behalf, calculate expected health factor, and then deposit with a different collateral amount than the expected one
        (, int256 answer,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        kscAmountToMint = (collateralTokenAmount * (uint256(answer) * kscEngine.getAdditionalFeedPrecision()))
            / kscEngine.getPrecisionFactor(); // just return the price of the KSC to mint
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(kscEngine), collateralTokenAmount);
        uint256 expectedHealthFactor = kscEngine.calculateHealthFactor(
            kscAmountToMint, kscEngine.getUSDConversionRate(weth, collateralTokenAmount)
        );
        vm.expectRevert(
            abi.encodeWithSelector(KSCEngine.KSCEngine__HealthFactorIsBroken.selector, expectedHealthFactor)
        );
        kscEngine.depositCollateralAndMintKSC(address(weth), collateralTokenAmount, kscAmountToMint);
        vm.stopPrank();
    }

    function testUserCanMintWithDepositedCollateral() public depositedCollateralAndMintedKSC {
        uint256 userBalance = ksc.balanceOf(user);
        console.log("KSC amount is: %", kscAmountToMint);
        assertEq(userBalance, kscAmountToMint);
    }

    ///@notice this test needs its own setup because we're working on a mocked token (a normal ERC20 wouldnt fail at minting)
    function testRevertIfKSCMintingFails() public {
        //setup
        address owner = msg.sender;
        MockFailedMintKSC mockDecentralizedStableCoin = new MockFailedMintKSC();
        collateralTokensAddresses = [address(weth)];
        collateralTokensPriceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        KSCEngine mockDecentralizedStableCoinEngine = new KSCEngine(
            collateralTokensAddresses, collateralTokensPriceFeedAddresses, address(mockDecentralizedStableCoin)
        );
        mockDecentralizedStableCoin.transferOwnership(address(mockDecentralizedStableCoinEngine));
        //user logic
        vm.startPrank(user);
        ERC20Mock(address(weth)).approve(address(mockDecentralizedStableCoinEngine), collateralTokenAmount);
        vm.expectRevert(KSCEngine.KSCEngine__MintFailed.selector);
        mockDecentralizedStableCoinEngine.depositCollateralAndMintKSC(
            address(weth), collateralTokenAmount, kscAmountToMint
        );
        vm.stopPrank();
    }

    function testRevertIfKSCMintAmountIsZero() public depositedCollateral {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(kscEngine), collateralTokenAmount);
        vm.expectRevert(KSCEngine.KSCEngine__AmountIsEqualToZeroYouNeedMore.selector);
        kscEngine.mintKSC(0);
        vm.stopPrank();
    }

    function testUserCanMintKSC() public depositedCollateralAndMintedKSC {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(kscEngine), collateralTokenAmount);
        (uint256 totalKSCMinted,) = kscEngine.getAccountInfo(user);
        assertEq(kscAmountToMint, totalKSCMinted);
        vm.stopPrank();
    }

    function testRevertIfKSCBurnAmountIsZero() public depositedCollateralAndMintedKSC {
        vm.expectRevert(KSCEngine.KSCEngine__AmountIsEqualToZeroYouNeedMore.selector);
        kscEngine.burnKSC(0);
    }

    function testRevertIfUserTriesToBurnMoreKSCThanTheyHave() public {
        vm.prank(user);
        vm.expectRevert();
        kscEngine.burnKSC(1);
    }

    function testUserCanBurnKSC() public depositedCollateralAndMintedKSC {
        vm.startPrank(user);
        ERC20Mock(address(ksc)).approve(address(kscEngine), kscAmountToMint); // we can even let go of this, because _burnKSC takes on msg.sender and msg.sender as parameters for onBehalfOf and From, which will work fine since we're pranking our user
        (uint256 userKSCBalance,) = kscEngine.getAccountInfo(user);
        console.log("User KSC Balance: %s", userKSCBalance);
        kscEngine.burnKSC(kscAmountToMint);
        (uint256 newUserKSCBalance,) = kscEngine.getAccountInfo(user);
        assertEq(newUserKSCBalance, 0);
        vm.stopPrank();
    }

    function testRevertIfRedeemedAmountIsZero() public depositedCollateral {
        vm.startPrank(user);
        vm.expectRevert(KSCEngine.KSCEngine__AmountIsEqualToZeroYouNeedMore.selector);
        kscEngine.redeemCollateral(address(weth), 0);
        vm.stopPrank();
    }

    function testUserCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(user);
        kscEngine.redeemCollateral(address(weth), collateralTokenAmount);
        uint256 userCollateralBalance = kscEngine.getCollateralBalanceOfUser(user, address(weth));
        assertEq(userCollateralBalance, 0);
        vm.stopPrank();
    }

    function testEmitCollateralRedeemedCorrectly() public depositedCollateral {
        vm.expectEmit(true, true, true, true, address(kscEngine));
        emit CollateralRedeemed(user, user, weth, collateralTokenAmount); //declaring the exact event and values expected, now foundry will check for the next emitted event and check if it matches
        vm.startPrank(user);
        kscEngine.redeemCollateral(weth, collateralTokenAmount);
        vm.stopPrank();
    }

    function testUserMustRedeemAmountMoreThanZero() public depositedCollateral {
        vm.expectRevert(KSCEngine.KSCEngine__AmountIsEqualToZeroYouNeedMore.selector);
        vm.prank(user);
        kscEngine.redeemCollateral(weth, 0);
    }

    function testUserCanRedeemDepositedCollateral() public depositedCollateralAndMintedKSC {
        vm.startPrank(user);
        uint256 initialUserKSCBalance = ksc.balanceOf(user);
        assertEq(initialUserKSCBalance, kscAmountToMint);
        ksc.approve(address(kscEngine), kscAmountToMint);
        kscEngine.redeemCollateralInExchangeForKSC(weth, collateralTokenAmount, kscAmountToMint);
        uint256 finalUserKSCBalance = ksc.balanceOf(user);
        assertEq(finalUserKSCBalance, 0);
        vm.stopPrank();
    }

    function testHealthFactorIsReportedProperly() public depositedCollateralAndMintedKSC {
        /**
         * 100$ minted with 20000$ collateral at 50% liquidation threshold
         * => must have at least 200$ collateral at all times
         * 20000 * 0.5 = 10000
         * 10000 / 100 = 100 health factor
         */
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = kscEngine.getHealthFactor(user);
        assertEq(expectedHealthFactor, healthFactor);
    }

    function testHealthFactorCanGoUnderHealthyHealthFactor() public depositedCollateralAndMintedKSC {
        int256 ethUSDUpdatedPrice = 18e8; // 1ETH=18$ => we crash the ETH price
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUSDUpdatedPrice);
        uint256 userHealthFactor = kscEngine.getHealthFactor(user);
        // 180*50 (180 cuz we minted 100KSC)(LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalDscMinted) =
        // 0.9
        assert(userHealthFactor == 0.9 ether);
    }

    // this test needs its own setup because we're gonna be crashing the market price on burning
    function testHealthFactorMustImproveOnLiquidation() public {
        //setup - Arrange
        MockMoreDebtKSC mockDecentralizedStableCoin = new MockMoreDebtKSC(ethUsdPriceFeed);
        collateralTokensAddresses = [weth];
        collateralTokensPriceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        KSCEngine mockDecentralizedStableCoinEngine = new KSCEngine(
            collateralTokensAddresses, collateralTokensPriceFeedAddresses, address(mockDecentralizedStableCoin)
        );
        mockDecentralizedStableCoin.transferOwnership(address(mockDecentralizedStableCoinEngine));

        //User - Arrange
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockDecentralizedStableCoinEngine), collateralTokenAmount);
        mockDecentralizedStableCoinEngine.depositCollateralAndMintKSC(weth, collateralTokenAmount, kscAmountToMint);
        vm.stopPrank();

        // Liquidator - Arrange
        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);
        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(mockDecentralizedStableCoinEngine), collateralToCover);
        uint256 debtToCover = 10 ether;
        mockDecentralizedStableCoinEngine.depositCollateralAndMintKSC(weth, collateralToCover, kscAmountToMint);
        mockDecentralizedStableCoin.approve(address(mockDecentralizedStableCoinEngine), debtToCover);

        //Act
        int256 ethUsdUpdatedPrice = 18e8;
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        //Act/Assert
        vm.expectRevert(KSCEngine.KSCEngine__HealthFactorDidNotImprove.selector);
        mockDecentralizedStableCoinEngine.liquidateAssets(weth, user, debtToCover);
        vm.stopPrank();
    }

    function testLiquidatorCannotLiquidateAUserWithGoodHealthFactor() public depositedCollateralAndMintedKSC {
        ERC20Mock(weth).mint(liquidator, collateralToCover);
        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(kscEngine), collateralToCover);
        kscEngine.depositCollateralAndMintKSC(weth, collateralToCover, kscAmountToMint);
        ksc.approve(address(kscEngine), kscAmountToMint);

        vm.expectRevert(KSCEngine.KSCEngine__UserHealthFactorIsOK.selector);
        kscEngine.liquidateAssets(weth, user, kscAmountToMint);

        vm.stopPrank();
    }

    function testLiquidationPayoutForLiquidatorIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        console.log("liquidator weth balance is: %s ", liquidatorWethBalance);
        uint256 expectedWeth = kscEngine.getAccountCollateralTokenAmountFromUsd(weth, kscAmountToMint)
            + (
                (kscEngine.getAccountCollateralTokenAmountFromUsd(weth, kscAmountToMint) * kscEngine.getLiquidationBonus())
                    / kscEngine.getLiquidationPrecision()
            );
        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    function testUserStillHasSomeETHAfterBeingLiquidated() public liquidated {
        //first we gotta determine how much the user lost
        uint256 amountLiquidated = kscEngine.getAccountCollateralTokenAmountFromUsd(weth, kscAmountToMint)
            + (
                kscEngine.getAccountCollateralTokenAmountFromUsd(weth, kscAmountToMint) * kscEngine.getLiquidationBonus()
                    / kscEngine.getLiquidationPrecision()
            );
        uint256 usdAmountLiquidated = kscEngine.getUSDConversionRate(weth, amountLiquidated);
        uint256 expectedUserCollateralValueInUsd =
            kscEngine.getUSDConversionRate(weth, collateralTokenAmount) - (usdAmountLiquidated);

        (, uint256 userCollateralValueInUsd) = kscEngine.getAccountInfo(user);
        uint256 hardCodedExpectedValue = 70_000_000_000_000_000_020;
        assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
        assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnLiquidatedUserDebt() public liquidated {
        (uint256 liquidatorKSCMinted,) = kscEngine.getAccountInfo(liquidator);
        assertEq(liquidatorKSCMinted, kscAmountToMint);
    }

    function testLiquidatedUserHasNoMoreDebt() public liquidated {
        (uint256 userKSCMinted,) = kscEngine.getAccountInfo(user);
        assertEq(userKSCMinted, 0);
    }

    /*//////////////////////////////////////////////////////////////
                      PURE AND VIEW FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/
    function testGetCollateralTokenPriceFeed() public view {
        address collateralTokenPriceFeed = kscEngine.getCollateralTokenPriceFeed(weth);
        assertEq(collateralTokenPriceFeed, ethUsdPriceFeed);
    }

    function testGetCollateralTokens() public view {
        address[] memory collateralTokenAddress = kscEngine.getCollateralTokens();
        assertEq(collateralTokenAddress[0], weth);
        assertEq(collateralTokenAddress[1], wbtc);
    }

    function testGetMinimumHealthFactorValue() public view {
        uint256 expectedHealthFactor = kscEngine.getMinHealthFactor();
        assertEq(MINIMUM_HEALTH_FACTOR, expectedHealthFactor);
    }

    function testGetLiquidationThreshold() public view {
        uint256 expectedLiquidationThreshold = kscEngine.getLiquidationThreshold();
        assertEq(expectedLiquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValueFromAccountInformation() public depositedCollateral {
        (, uint256 accountCollateralValue) = kscEngine.getAccountInfo(user);
        uint256 expectecAccountCollateralValue = kscEngine.getUSDConversionRate(weth, collateralTokenAmount);
        assertEq(expectecAccountCollateralValue, accountCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public depositedCollateral {
        uint256 collateralBalance = kscEngine.getCollateralBalanceOfUser(user, weth);
        assertEq(collateralBalance, collateralTokenAmount);
    }

    function testGetAccountCollateralValue() public depositedCollateral {
        uint256 accountCollateralValue = kscEngine.getAccountCollateralValue(user);
        uint256 expectedAccountCollateralValue = kscEngine.getUSDConversionRate(weth, collateralTokenAmount);
        assertEq(expectedAccountCollateralValue, accountCollateralValue);
    }

    function testGetKSC() public view {
        address kscAddress = kscEngine.getKSCContractAddress();
        assertEq(kscAddress, address(ksc));
    }

    function testGetLiquidationPrecision() public view {
        uint256 liquidationPrecision = kscEngine.getLiquidationPrecision();
        assertEq(100, liquidationPrecision);
    }
}
