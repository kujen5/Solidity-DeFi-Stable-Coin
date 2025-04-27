// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import { MockV3Aggregator } from "./MockV3Aggregator.sol";


/// @title MockMoreDebtKSC
/// @author Foued SAIDI - 0xkujen
/// @notice this mock is meant to test if our engine correctly handles a stablecoin's collapse during burn, and check if the system stays safe
contract MockMoreDebtKSC is ERC20Burnable, Ownable(msg.sender) {
    error MockFailedTransfer__AmountToBurnMustBeStriclyBiggerThanZero();
    error MockFailedTransfer__AmountToBurnMustBeEqualToOrHigherThanUserBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    address mockAggregator;
    constructor(address _mockAggregator) ERC20("DecentralizedStableCoin", "DSC") {
        mockAggregator = _mockAggregator;
    }

    function burn(uint256 _amount) public override onlyOwner {
        // we update the answer with a wrong value so it crashes
        MockV3Aggregator(mockAggregator).updateAnswer(0);
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert MockFailedTransfer__AmountToBurnMustBeStriclyBiggerThanZero();
        }
        if (balance < _amount) {
            revert MockFailedTransfer__AmountToBurnMustBeEqualToOrHigherThanUserBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert MockFailedTransfer__AmountToBurnMustBeStriclyBiggerThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}

