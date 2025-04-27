// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockFailedTransferFrom
/// @author Foued SAIDI - 0xkujen
/// @notice this mock is meant to test if our engine correctly handles when another contract (vault, engine,..) tries to pull tokens using transferFrom and it fails

contract MockFailedTransferFrom is ERC20Burnable, Ownable(msg.sender) {
    error MockFailedTransfer__AmountToBurnMustBeStriclyBiggerThanZero();
    error MockFailedTransfer__AmountToBurnMustBeEqualToOrHigherThanUserBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("KujenStableCoin", "KSC") {}

    function burn(uint256 p_amountToBurn) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (p_amountToBurn <= 0) {
            revert MockFailedTransfer__AmountToBurnMustBeStriclyBiggerThanZero();
        }
        if (balance < p_amountToBurn) {
            revert MockFailedTransfer__AmountToBurnMustBeEqualToOrHigherThanUserBalance();
        }
        super.burn(p_amountToBurn);
    }

    function mint(address p_account, uint256 p_amountToMint) public {
        _mint(p_account, p_amountToMint);
    }

    function transferFrom(
        address,
        /*sender*/
        address,
        /*recipient*/
        uint256 /*amount*/
    ) public pure override returns (bool) {
        return false;
    }
}
