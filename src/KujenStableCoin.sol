// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract KujenStableCoin is ERC20Burnable, Ownable {
    error KujenStableCoin__AmountMustBeMoreThanZero();
    error KujenStableCoin__AmountToBeBurntExceedsBalanceAvailable();
    error KujenStableCoin__AmountMustBeBiggerThanZero();
    error KujenStableCoin__NotZeroAddress();

    constructor() ERC20("KujenStableCoin", "KSC") Ownable(msg.sender) {}

    function burn(uint256 p_amountToBeBurned) public override onlyOwner {
        uint256 availableBalance = balanceOf(msg.sender);
        if (p_amountToBeBurned <= 0) {
            revert KujenStableCoin__AmountMustBeMoreThanZero();
        }
        if (availableBalance < p_amountToBeBurned) {
            revert KujenStableCoin__AmountToBeBurntExceedsBalanceAvailable();
        }
        super.burn(p_amountToBeBurned);
    }

    function mint(address _toAddress, uint256 _amountToBeSent) external onlyOwner returns (bool) {
        if (_toAddress == address(0)) {
            revert KujenStableCoin__NotZeroAddress();
        }
        if (_amountToBeSent <= 0) {
            revert KujenStableCoin__AmountMustBeBiggerThanZero();
        }
        _mint(_toAddress, _amountToBeSent);
        return true;
    }
}
