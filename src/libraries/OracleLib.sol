// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author Foued SAIDI - 0xkujen
 * @notice This Library is meant to check if the price feeds data that we are using are too old to be trusted anymore.
 * If a price is stale (too old), functions will revert and the Engine will become unusable.
 */
library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(AggregatorV3Interface chainlinkPriceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            chainlinkPriceFeed.latestRoundData();
        if (updatedAt == 0 || answeredInRound < roundId) {
            //if it has not been updated or the latest answer is not on the current round (roundId)
            revert OracleLib__StalePrice();
        }
        uint256 secondsSinceLastUpdate = block.timestamp - updatedAt;
        if (secondsSinceLastUpdate > TIMEOUT) revert OracleLib__StalePrice(); // if the latest update was more than 3 hours ago, revert
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
