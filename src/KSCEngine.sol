// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {KujenStableCoin} from "./KujenStableCoin.sol";
import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title KSCEngine
 * @author Foued SAIDI - 0xkujen
 *
 * We want to have our KSC token maintain a 1KSC==1$ peg, always.
 * The system must always be overcollateralized.
 */
contract KSCEngine is
    ReentrancyGuard // to protect from reentrancy attacks, will make a project about it in the future
{
    error KSCEngine__AmountIsEqualToZeroYouNeedMore();
    error KSCEngine__TokenIsNotAllowed();
    error KSCEngine__collateralTokenAddressesAndPriceFeedsAmountDoNotMatch();
    error KSCEngine__TransferFailed();
    error KSCEngine__HealthFactorIsBroken(uint256 userHealthFactor);
    error KSCEngine__MintFailed();
    error KSCEngine__KSCTransferFailed();
    error KSCEngine__UserHealthFactorIsOK();
    error KSCEngine__HealthFactorDidNotImprove();

    using OracleLib for AggregatorV3Interface;

    KujenStableCoin private immutable i_ksc;

    /// @notice  means we are 200% overcollateralized -> we deposit 100$ we get 50$ worth of KSC
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    /// @notice means a liquidator gets 10% off when liquidating -> gets
    uint256 private constant LIQUIDATION_BONUS_FOR_LIQUIDATORS = 10;
    /// @notice basically means we're working with percentages
    uint256 private constant LIQUIDATION_PRECISION_FACTOR = 100;
    /// @notice meaning if a user is under-collateralized we'll revert (this value is compared to the value resulting from calculating if we're over-collateralized or not)
    uint256 private constant MINIMUM_HEALTH_FACTOR = 1e18;
    /// @notice basically just to convert values to be compatible for our precision factors
    uint256 private constant PRECISION = 1e18;
    ///@notice this is basically used to transform the returned pricefeed answer from 8 decimals (default) to 18 decimals
    uint256 private constant PRICEFEED_DECIMALS_PRECISION = 1e10;

    mapping(address collateralTokenToBeDeposited => address priceFeed) private s_tokenToPriceFeedArray;
    mapping(address user => mapping(address collateralTokenAddress => uint256 collateralAmountToDeposit)) private
        s_collateralDeposited;
    mapping(address user => uint256 kscMintedAmount) s_KSCMinted;
    address[] private s_collateralTokensArray;

    event CollateralDeposited(address depositerAddress, address collateralTokenAddress, uint256 amountToBeDeposited);
    event CollateralRedeemed(
        address fromAddress, address toAddress, address collateralTokenAddress, uint256 collateralAmountToRedeem
    );

    modifier biggerThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert KSCEngine__AmountIsEqualToZeroYouNeedMore();
        }
        _; // injection point, we the function logic will be implemented
    }

    modifier isTokenAllowed(address _tokenAddress) {
        if (s_tokenToPriceFeedArray[_tokenAddress] == address(0)) {
            revert KSCEngine__TokenIsNotAllowed();
        }
        _;
    }

    constructor(
        address[] memory p_collateralTokensAddresses,
        address[] memory p_collateralTokensPriceFeeds,
        address p_kscAddress
    ) {
        /// @dev this basically means we either have too many price feed for token address or too few
        if (p_collateralTokensAddresses.length != p_collateralTokensPriceFeeds.length) {
            revert KSCEngine__collateralTokenAddressesAndPriceFeedsAmountDoNotMatch();
        }
        ///@dev assign each token address to its' corresponding price feed
        for (uint256 i; i < p_collateralTokensAddresses.length; i++) {
            s_tokenToPriceFeedArray[p_collateralTokensAddresses[i]] = p_collateralTokensPriceFeeds[i];
            s_collateralTokensArray.push(p_collateralTokensAddresses[i]);
        }
        i_ksc = KujenStableCoin(p_kscAddress);
    }

    function depositCollateralAndMintKSC(
        address p_collateralTokenAddress,
        uint256 p_collateralAmountToDeposit,
        uint256 p_kscAmountToMint
    ) external {
        depositCollateral(p_collateralTokenAddress, p_collateralAmountToDeposit);
        mintKSC(p_kscAmountToMint);
    }

    function redeemCollateralInExchangeForKSC(
        address p_collateralTokenAddress,
        uint256 p_collateralAmountToBeExchanged,
        uint256 p_kscAmountToBurn
    ) external biggerThanZero(p_collateralAmountToBeExchanged) isTokenAllowed(p_collateralTokenAddress) {
        _burnKSC(p_kscAmountToBurn, msg.sender, msg.sender); // on behalf of msg.sender, from msg.sender's balance
        _redeemCollateral(p_collateralTokenAddress, p_collateralAmountToBeExchanged, msg.sender, msg.sender); // redeem collateral deposited by msg.sender and send it to msg.sender's wallet
        revertIfHealthFactorIsNotMet(msg.sender); // you cannot redeem your deposited collateral if you have a bad health factor
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        biggerThanZero(amountCollateral)
        nonReentrant
        isTokenAllowed(tokenCollateralAddress)
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsNotMet(msg.sender);
    }

    function burnKSC(uint256 p_kscAmountToBurn) external biggerThanZero(p_kscAmountToBurn) {
        _burnKSC(p_kscAmountToBurn, msg.sender, msg.sender);
        revertIfHealthFactorIsNotMet(msg.sender);
    }

    function liquidateAssets(address p_collateralTokenAddress, address p_user, uint256 p_debtToCover)
        external
        nonReentrant
        biggerThanZero(p_debtToCover)
        isTokenAllowed(p_collateralTokenAddress)
    {
        uint256 startingUserHealthFactor = _healthFactor(p_user);
        if (startingUserHealthFactor >= MINIMUM_HEALTH_FACTOR) {
            revert KSCEngine__UserHealthFactorIsOK();
        }
        /**
         * the user has 100 KSC in debt, the corresponding price is 100 USD$
         * the liquidator will pay off the 100 KSC in debt, and SHOULD receive 100USD$
         * but they'll get an extra bonus, which is 10%, so they get 110$ for paying the 100 KSC debt
         * the liquidator will redem collateral + bonus, and then we burn the KSC paid
         */
        uint256 collateralTokenAmountFromDebt =
            getAccountCollateralTokenAmountFromUsd(p_collateralTokenAddress, p_debtToCover);
        uint256 bonusCollateralForLiquidator =
            (collateralTokenAmountFromDebt * LIQUIDATION_BONUS_FOR_LIQUIDATORS) / LIQUIDATION_PRECISION_FACTOR; // 10% of the collateral debt to cover
        _redeemCollateral(
            p_collateralTokenAddress, collateralTokenAmountFromDebt + bonusCollateralForLiquidator, p_user, msg.sender
        ); // liquidator (msg.sender) redeems debtToCover from the liquidated user
        _burnKSC(p_debtToCover, p_user, msg.sender); // remove the KSC debt from the user accountn
        uint256 finalUserHealthFactor = _healthFactor(p_user);
        if (finalUserHealthFactor <= startingUserHealthFactor) {
            // we'll probably never hit this revert but why not 8)
            revert KSCEngine__HealthFactorDidNotImprove();
        }
    }

    function mintKSC(uint256 p_kscAmountToMint) public nonReentrant biggerThanZero(p_kscAmountToMint) {
        s_KSCMinted[msg.sender] += p_kscAmountToMint;
        revertIfHealthFactorIsNotMet(msg.sender);
        bool minted = i_ksc.mint(msg.sender, p_kscAmountToMint);
        if (minted != true) {
            revert KSCEngine__MintFailed();
        }
    }

    function depositCollateral(address p_collateralTokenAddress, uint256 p_collateralAmountToDeposit)
        public
        nonReentrant
        isTokenAllowed(p_collateralTokenAddress)
    {
        s_collateralDeposited[msg.sender][p_collateralTokenAddress] += p_collateralAmountToDeposit;
        emit CollateralDeposited(msg.sender, p_collateralTokenAddress, p_collateralAmountToDeposit);
        ///@notice transfer the amount of X token from msg.sender to this contract's address
        bool success =
            IERC20(p_collateralTokenAddress).transferFrom(msg.sender, address(this), p_collateralAmountToDeposit);
        if (!success) {
            revert KSCEngine__TransferFailed();
        }
    }

    function _redeemCollateral(
        address p_collateralTokenAddress,
        uint256 p_collateralAmountToRedeem,
        address p_fromAddress,
        address p_toAddress
    ) private {
        s_collateralDeposited[p_fromAddress][p_collateralTokenAddress] -= p_collateralAmountToRedeem;
        emit CollateralRedeemed(p_fromAddress, p_toAddress, p_collateralTokenAddress, p_collateralAmountToRedeem);
        bool success = IERC20(p_collateralTokenAddress).transfer(p_toAddress, p_collateralAmountToRedeem);
        if (!success) {
            revert KSCEngine__KSCTransferFailed();
        }
    }

    function _burnKSC(uint256 p_kscAmountToBurn, address p_onBehalfOfUser, address p_kscFromUser) private {
        s_KSCMinted[p_onBehalfOfUser] -= p_kscAmountToBurn;
        bool success = i_ksc.transferFrom(p_kscFromUser, address(this), p_kscAmountToBurn); // we transfer the KSC from a lender to our Engine and then we burn it
        if (!success) {
            revert KSCEngine__KSCTransferFailed();
        }
        i_ksc.burn(p_kscAmountToBurn);
    }

    function _getAccountInfo(address p_user)
        private
        view
        returns (uint256 totalKSCMinted, uint256 collateralValueInUSD)
    {
        totalKSCMinted = s_KSCMinted[p_user];
        collateralValueInUSD = getAccountCollateralValue(p_user);
    }

    ///@notice this function retrieve the user's account information (user collateral's value and the KSC minted by the user) and then uses it to calculate the health factor
    function _healthFactor(address p_user) private view returns (uint256) {
        (uint256 totalKSCMinted, uint256 collateralValueInUSD) = _getAccountInfo(p_user);
        return _calculateHealthFactor(totalKSCMinted, collateralValueInUSD);
    }

    ///@notice this function returns the token's value in USD using chainlink's oracle
    function _getUSDConversionRate(address p_token, uint256 p_amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeedArray[p_token]);
        (, int256 usdPrice,,,) = priceFeed.staleCheckLatestRoundData();
        /*
        @notice we do this because the returned price from the oracle is 8 decimals. For example
        - 1ETH=2000USD
        => the returned price from the oracle = 2000 * 1e8 (8decimals => 200000000000)
        => so we multiply it by the decimals precision factor 1e10
        => it becomes 2000 * 1e8 * 1e10 = 2000 * 1e18
        => lastly we divide by the precision factor or 1e18
        => and we get 2000$
        */
        return ((uint256(usdPrice) * PRICEFEED_DECIMALS_PRECISION) * p_amount) / PRECISION;
    }

    function _calculateHealthFactor(uint256 p_totalKSCMinted, uint256 p_collateralValueInUSD)
        internal
        pure
        returns (uint256)
    {
        if (p_totalKSCMinted == 0) return type(uint256).max; // if user still hasnt minted any KSC, return the max of uint256
        uint256 collateralAdjustedForThreshold =
            (p_collateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION_FACTOR;
        return (collateralAdjustedForThreshold * PRECISION) / p_totalKSCMinted; // we divide USD by a the unitless KSC amount, because 1KSC=1USD so its basically USD/USD
    }

    ///@notice revertIfHealthFactorIsNotMet reverts if the user's health factor is broken => means if the user is over-collateralized or under-collateralized
    function revertIfHealthFactorIsNotMet(address p_user) internal view {
        uint256 userHealthFactor = _healthFactor(p_user);
        if (userHealthFactor < MINIMUM_HEALTH_FACTOR) {
            revert KSCEngine__HealthFactorIsBroken(userHealthFactor);
        }
    }

    function getAccountInfo(address p_user)
        external
        view
        returns (uint256 totalKSCMinted, uint256 collateralValueInUSD)
    {
        return _getAccountInfo(p_user);
    }

    function calculateHealthFactor(uint256 p_totalKSCMinted, uint256 p_collateralValueInUSD)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(p_totalKSCMinted, p_collateralValueInUSD);
    }

    function getUSDConversionRate(address p_token, uint256 p_amount) external view returns (uint256) {
        return _getUSDConversionRate(p_token, p_amount);
    }

    function getCollateralBalanceOfUser(address p_user, address p_collateralTokenAddres)
        external
        view
        returns (uint256)
    {
        return s_collateralDeposited[p_user][p_collateralTokenAddres];
    }

    ///@notice this function calculates the cumulated user's deposited collateral for all the token and gets its value in USD
    function getAccountCollateralValue(address p_user) public view returns (uint256 totalCollateralValueInUSD) {
        for (uint256 i; i < s_collateralTokensArray.length; i++) {
            address token = s_collateralTokensArray[i];
            uint256 amount = s_collateralDeposited[p_user][token];
            totalCollateralValueInUSD += _getUSDConversionRate(token, amount);
        }
        return totalCollateralValueInUSD;
    }

    function getAccountCollateralTokenAmountFromUsd(address p_collateralTokenAddress, uint256 p_usdAmount)
        public
        view
        returns (uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeedArray[p_collateralTokenAddress]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return (p_usdAmount * PRECISION) / (uint256(price) * PRICEFEED_DECIMALS_PRECISION);
    }

    function getPrecisionFactor() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return PRICEFEED_DECIMALS_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS_FOR_LIQUIDATORS;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MINIMUM_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokensArray;
    }

    function getKSCContractAddress() external view returns (address) {
        return address(i_ksc);
    }

    function getCollateralTokenPriceFeed(address p_token) external view returns (address) {
        return s_tokenToPriceFeedArray[p_token];
    }

    function getHealthFactor(address p_user) external view returns (uint256) {
        return _healthFactor(p_user);
    }
}
