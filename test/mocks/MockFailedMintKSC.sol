// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockFailedMintKSC
/// @author Foued SAIDI - 0xkujen
/// @notice this mock is meant to test if our engine correctly handles the case where minting KSC token fails

contract MockFailedMintKSC is ERC20Burnable, Ownable(msg.sender) {
    error MockFailedTransfer__AmountToBurnMustBeStriclyBiggerThanZero();
    error MockFailedTransfer__AmountToBurnMustBeEqualToOrHigherThanUserBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC") {}

    function burn(uint256 _amount) public override onlyOwner {
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
        // mint function returns false on purpose
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert MockFailedTransfer__AmountToBurnMustBeStriclyBiggerThanZero();
        }
        _mint(_to, _amount);
        return false;
    }
}
