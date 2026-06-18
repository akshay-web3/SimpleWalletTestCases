// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SimpleWallet} from "../src/SimpleWallet.sol";

contract SimpleWalletTest is Test {
    SimpleWallet wallet;

    address owner;
    address alice;
    address bob;

    receive() external payable {}

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        wallet = new SimpleWallet();
    }

    function testDeployerIsOwner() public view {
        assertEq(wallet.walletOwner(), owner);
    }

    function testDepositEther() public {
        uint256 startTime = block.timestamp - 1;
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        wallet.depositToContract{value: 1 ether}(startTime);

        assertEq(wallet.getContractBalanceInWei(), 1 ether);
        SimpleWallet.Transaction[] memory transaction = wallet
            .getTransactionHistory();

        assertTrue(transaction.length == 1);
    }

    function testOnlyOwnerCanTransfer() public {
        vm.prank(alice);
        vm.expectRevert(SimpleWallet.Unauthorized.selector);
        wallet.transferFromContract(payable(bob), 1 ether);
    }

    function testOwnerFundTransferToUser() public {
        uint256 startTime = block.timestamp - 1;
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        wallet.depositToContract{value: 5 ether}(startTime);
        wallet.transferFromContract(payable(bob), 2 ether);
        assertEq(bob.balance, 2 ether);
        assertEq(wallet.getContractBalanceInWei(), 3 ether);
        SimpleWallet.Transaction[] memory transactions = wallet
            .getTransactionHistory();
        assertEq(transactions.length,2);
    }

    function testEmergencyMode() public {
        uint256 startTime = block.timestamp - 1;
        wallet.toggleEmergencyMode();
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        vm.expectRevert(SimpleWallet.EmergencyActive.selector);
        wallet.depositToContract{value: 5 ether}(startTime);
    }

    function testEmergencyWithdrawal() public {
        uint256 startTime = block.timestamp - 1;
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        wallet.depositToContract{value: 10 ether}(startTime);

        uint256 ownerBalanceBeforeEmergency = address(this).balance;
        uint256 contractBalanceBeforeEmergency = wallet
            .getContractBalanceInWei();

        assertEq(contractBalanceBeforeEmergency, 10 ether);
        wallet.toggleEmergencyMode();
        wallet.emergencyWithdrawal();

        uint256 ownerBalanceAfterEmergency = wallet.getOwnerBalanceInWei();
        uint256 contractBalanceBeafterEmergency = wallet
            .getContractBalanceInWei();
        assertEq(contractBalanceBeafterEmergency, 0 ether);
        assertEq(
            ownerBalanceAfterEmergency,
            ownerBalanceBeforeEmergency + 10 ether
        );
    }

    function testVerifyTransactionRecords() public {
        uint256 startTime = block.timestamp - 1;
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        wallet.depositToContract{value: 5 ether}(startTime);
        wallet.transferFromContract(payable(bob), 2 ether);

        SimpleWallet.Transaction[] memory transactions = wallet
            .getTransactionHistory();
        assertTrue(transactions.length == 2);
        assertEq(transactions[0].sender, address(alice));
        assertEq(transactions[0].receiver, address(wallet));
        assertEq(transactions[0].amount, 5 ether);

        assertEq(transactions[1].sender, address(wallet));
        assertEq(transactions[1].receiver, address(bob));
        assertEq(transactions[1].amount, 2 ether);
    }
}
