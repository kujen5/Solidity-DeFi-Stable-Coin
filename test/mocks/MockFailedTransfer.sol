// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockFailedTransfer
/// @author Foued SAIDI - 0xkujen
/// @notice this mock is meant to test if our engine correctly handles the case where a transfer operation (sending stablecoin or collateral) fails

contract MockFailedTransfer is ERC20Burnable, Ownable(msg.sender) {
    error MockFailedTransfer__AmountToBurnMustBeStriclyBiggerThanZero();
    error MockFailedTransfer__AmountToBurnMustBeEqualToOrHigherThanUserBalance();

    constructor() ERC20("KujenStableCoin", "KSC") {}

    function burn(uint256 p_amountToBurn) public override onlyOwner {
        uint256 userBalance = balanceOf(msg.sender);
        if (p_amountToBurn <= 0) {
            revert MockFailedTransfer__AmountToBurnMustBeStriclyBiggerThanZero();
        }
        if (userBalance < p_amountToBurn) {
            revert MockFailedTransfer__AmountToBurnMustBeEqualToOrHigherThanUserBalance();
        }
        super.burn(p_amountToBurn);
    }

    function mint(address p_account, uint256 p_amountToMint) public {
        _mint(p_account, p_amountToMint);
    }

    function transfer(
        // we are making the transfer function fail on purpose to test out the behavior upon failure
        address, /*recipient*/
        uint256 /*amount*/
    ) public pure override returns (bool) {
        return false;
    }
}
