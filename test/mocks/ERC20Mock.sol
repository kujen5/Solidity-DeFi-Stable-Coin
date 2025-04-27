// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(
        string memory p_tokenName,
        string memory p_tokenSymbol,
        address p_initialAccount,
        uint256 p_initialBalance
    ) payable ERC20(p_tokenName, p_tokenSymbol) {
        _mint(p_initialAccount, p_initialBalance);
    }

    function mint(address p_account, uint256 p_amounToBeMinted) public {
        _mint(p_account, p_amounToBeMinted);
    }

    function burn(address p_account, uint256 p_amountToBeBurned) public {
        _burn(p_account, p_amountToBeBurned);
    }

    function transferInternally(address p_fromUser, address p_toUser, uint256 p_amount) public {
        _transfer(p_fromUser, p_toUser, p_amount);
    }

    function approveInternally(address p_owner, address p_spender, uint256 p_amount) public {
        _approve(p_owner, p_spender, p_amount);
    }
}
