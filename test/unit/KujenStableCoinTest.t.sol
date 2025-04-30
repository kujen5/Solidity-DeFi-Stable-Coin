// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import{console} from "forge-std/console.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import {KujenStableCoin} from "../../src/KujenStableCoin.sol";


contract KujenStableCoinTest is StdCheats,Test {
    KujenStableCoin ksc;
    function setUp() public {
        ksc=new KujenStableCoin();
    }
    function testUserMustMintMoreThanZero() public {
        vm.startPrank(ksc.owner());
        vm.expectRevert(KujenStableCoin.KujenStableCoin__AmountMustBeBiggerThanZero.selector);
        ksc.mint(msg.sender,0);

        vm.stopPrank();
    }
    function testUserMustBurnMoreThanZero() public {
        vm.startPrank(ksc.owner());
        vm.expectRevert(KujenStableCoin.KujenStableCoin__AmountMustBeMoreThanZero.selector);
        ksc.burn(0);
        vm.stopPrank();
    }
    function testUserCantBurnMoreThanHeHas() public {
        vm.startPrank(ksc.owner());
        ksc.mint(address(this), 10);
        vm.expectRevert(KujenStableCoin.KujenStableCoin__AmountToBeBurntExceedsBalanceAvailable.selector);
        ksc.burn(11);
        vm.stopPrank();
    }
    function testUserCantMintToZeroAddress() public {
        vm.startPrank(ksc.owner());
        vm.expectRevert(KujenStableCoin.KujenStableCoin__NotZeroAddress.selector);
        ksc.mint(address(0),1);
        vm.stopPrank();
    }


}
