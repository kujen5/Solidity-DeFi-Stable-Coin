// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title MockV3Aggregator
 * @notice Based on the FluxAggregator contract: https://github.com/smartcontractkit/chainlink/blob/86ed34cff2cc01e5c5d38369117fdf495109ed81/contracts/src/v0.6/FluxAggregator.sol
 * @notice Use this contract when you need to test
 * other contract's ability to read data from an
 * aggregator contract, but how the aggregator got
 * its answer is unimportant
 */
contract MockV3Aggregator is
    AggregatorV3Interface // we inherit all the functions inside of AggregatorV3Interface and define new ones
{
    uint256 public constant version = 4;

    uint8 public decimals; // decimals is the number of decimals the answer has (8 decimals for example here)
    int256 public latestAnswer; // latestAnswer is the latest/value answer given by the oracle
    uint256 public latestTimestamp; // latestTimestamp is the latest timestamp the answer was recorded in
    uint256 public latestRound; // latestRound is the latest round/cycle number

    mapping(uint256 => int256) public getAnswer; // getAnswer is a mapping of roundId to answer
    mapping(uint256 => uint256) public getTimestamp; // getTimestamp is a mapping of roundId to timestamp
    mapping(uint256 => uint256) private getStartedAt; // getStartedAt is a mapping of roundId to startedAt

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals;
        updateAnswer(_initialAnswer);
    }

    function updateAnswer(int256 _answer) public {
        // we're basically just taking an answer (price), incrementing the roundID (new round) and updating the data for it on our mappings
        latestAnswer = _answer;
        latestTimestamp = block.timestamp;
        latestRound++;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = block.timestamp;
        getStartedAt[latestRound] = block.timestamp;
    }

    function updateRoundData(
        // updating the metadata of our round (roundId, answer, timestamp, startedAt)
        uint80 _roundId,
        int256 _answer,
        uint256 _timestamp,
        uint256 _startedAt
    ) public {
        latestRound = _roundId;
        latestAnswer = _answer;
        latestTimestamp = _timestamp;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = _timestamp;
        getStartedAt[latestRound] = _startedAt;
    }

    function getRoundData(
        // just a getter for our round data from a specific roundID
        uint80 _roundId
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, getAnswer[_roundId], getStartedAt[_roundId], getTimestamp[_roundId], _roundId);
    }

    function latestRoundData()
        external
        view
        returns (
            // just a getter of the latest round data
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            uint80(latestRound),
            getAnswer[latestRound],
            getStartedAt[latestRound],
            getTimestamp[latestRound],
            uint80(latestRound)
        );
    }

    function description() external pure returns (string memory) {
        return "v0.6/test/mock/MockV3Aggregator.sol";
    }
}
