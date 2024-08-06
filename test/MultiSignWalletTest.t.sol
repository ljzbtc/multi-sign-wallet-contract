// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiSignWallet.sol";

contract MultiSignWalletTest is Test {
    MultiSignWallet public wallet;
    address[] public owners;
    uint256 public constant REQUIRED_CONFIRMATIONS = 2;

    address public owner1 = address(1);
    address public owner2 = address(2);
    address public owner3 = address(3);
    address public nonOwner = address(4);

    function setUp() public {
        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultiSignWallet(owners, REQUIRED_CONFIRMATIONS);
    }

    function testWalletCreation() public view {
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertFalse(wallet.isOwner(nonOwner));
        assertEq(wallet.numConfirmationsRequired(), REQUIRED_CONFIRMATIONS);
    }

    function testPostTransaction() public {
        vm.prank(owner1);
        wallet.postTx("", 1 ether, address(5));

        (, , address poster, address to, uint256 amount, , uint confirmations, MultiSignWallet.Status status) = wallet.transactions(0);

        assertEq(poster, owner1);
        assertEq(to, address(5));
        assertEq(amount, 1 ether);
        assertEq(uint(status), uint(MultiSignWallet.Status.PENDING));
        assertEq(confirmations, 1); // Auto-confirmed by poster
    }

    function testConfirmTransaction() public {
        vm.prank(owner1);
        wallet.postTx("", 1 ether, address(5));

        vm.prank(owner2);
        wallet.confirmTx(0);

        (, , , , , , uint confirmations, MultiSignWallet.Status status) = wallet.transactions(0);

        assertEq(confirmations, 2);
        assertEq(uint(status), uint(MultiSignWallet.Status.CONFIRMED));
    }

    function testExecuteTransaction() public {
        address payable recipient = payable(address(5));
        uint256 initialBalance = recipient.balance;

        vm.deal(address(wallet), 2 ether); // Fund the wallet

        vm.prank(owner1);
        wallet.postTx("", 1 ether, recipient);

        vm.prank(owner2);
        wallet.confirmTx(0);

        vm.prank(owner3);
        wallet.executeTx(0);

        assertEq(recipient.balance, initialBalance + 1 ether);
    }

    function testFailNonOwnerPostTransaction() public {
        vm.prank(nonOwner);
        wallet.postTx("", 1 ether, address(5));
    }

    function testGetPendings() public {
        vm.startPrank(owner1);
        wallet.postTx("", 1 ether, address(5));
        wallet.postTx("", 2 ether, address(6));
        vm.stopPrank();

        uint[] memory pendingTxs = wallet.getPendings();
        assertEq(pendingTxs.length, 2);
        assertEq(pendingTxs[0], 0);
        assertEq(pendingTxs[1], 1);
    }
}