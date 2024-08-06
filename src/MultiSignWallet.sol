// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IMultiSignWallet.sol";

contract MultiSignWallet is IMultiSignWallet {
    enum Status {
        PENDING,
        CONFIRMED,
        EXECUTED,
        CANCELED
    }

    struct Transaction {
        uint256 postTime;
        uint txId;
        address poster;
        address to;
        uint256 amount;
        bytes data;
        uint confirmations;
        Status status;
    }

    mapping(address => bool) public isOwner;
    address[] public owners;
    uint[] public pendingTransactions;
    uint public numConfirmationsRequired;
    uint public txNonce;
    Transaction[] public transactions;
    mapping(address => mapping(uint => bool)) public isConfirmed;

    event WalletCreated();
    event TransactionPosted(
        uint indexed txId,
        address indexed poster,
        address indexed to,
        uint amount
    );
    event TransactionConfirmed(uint indexed txId, address indexed confirmer);
    event TransactionExecuted(uint indexed txId);

    error MultiSignWallet_NeedMoreThanOneOwner();
    error MultiSignWallet_NeedMoreThanOneConfirmation();
    error MultiSignWallet_OwnerNotUnique();
    error MultiSignWallet_InvalidOwner();
    error MultiSignWallet_ConfirmationNumMoreThanOwnerNum();
    error MultiSignWallet_NotOwner();
    error MultiSignWallet_AlreadyConfirmed();
    error MultiSignWallet_TransactionNotPending();
    error MultiSignWallet_TransactionNotConfirmed();
    error MultiSignWallet_InvalidToAddress();

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) {
            revert MultiSignWallet_NotOwner();
        }
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        if (_owners.length < 1) {
            revert MultiSignWallet_NeedMoreThanOneOwner();
        }

        if (_numConfirmationsRequired < 1) {
            revert MultiSignWallet_NeedMoreThanOneConfirmation();
        }
        if (_numConfirmationsRequired > _owners.length) {
            revert MultiSignWallet_ConfirmationNumMoreThanOwnerNum();
        }

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0)) {
                revert MultiSignWallet_InvalidOwner();
            }
            if (isOwner[owner]) {
                revert MultiSignWallet_OwnerNotUnique();
            }

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;

        emit WalletCreated();
    }

    function postTx(
        bytes calldata _data,
        uint amount,
        address to
    ) external onlyOwner {
        if (to == address(0)) {
            revert MultiSignWallet_InvalidToAddress();
        }

        

        Transaction memory newTx = Transaction({
            postTime: block.timestamp,
            txId: txNonce,
            poster: msg.sender,
            to: to,
            amount: amount,
            data: _data,
            confirmations: 0,
            status: Status.PENDING
        });

        transactions.push(newTx);
        pendingTransactions.push(newTx.txId);
        emit TransactionPosted(newTx.txId, msg.sender, to, amount);
        txNonce++;

        _confirmTx(msg.sender, newTx.txId);
        
    }

    function confirmTx(uint _txId) external onlyOwner {
        _confirmTx(msg.sender, _txId);
        emit TransactionConfirmed(_txId, msg.sender);
    }

    function getPendings() external view returns (uint[] memory) {
        uint pendingCount = 0;

        for (uint i = 0; i < transactions.length; i++) {
            if (transactions[i].status == Status.PENDING) {
                pendingCount++;
            }
        }

        uint[] memory pendingTxIds = new uint[](pendingCount);

        uint currentIndex = 0;
        for (uint i = 0; i < transactions.length; i++) {
            if (transactions[i].status == Status.PENDING) {
                pendingTxIds[currentIndex] = transactions[i].txId;
                currentIndex++;
            }
        }

        return pendingTxIds;
    }

    function executeTx(uint _txId) external  {
        Transaction storage transaction = transactions[_txId];

        if (transaction.status != Status.CONFIRMED) {
            revert MultiSignWallet_TransactionNotConfirmed();
        }

        (bool success, ) = transaction.to.call{value: transaction.amount}(
            transaction.data
        );
        require(success, "Transaction failed");

        transaction.status = Status.EXECUTED;

        emit TransactionExecuted(_txId);
    }

    function getTransaction(
        uint _txId
    ) external view returns (Transaction memory) {
        return transactions[_txId];
    }

    function _confirmTx(address _sender, uint _txId) internal {
        if (isConfirmed[_sender][_txId] == true) {
            revert MultiSignWallet_AlreadyConfirmed();
        }

        Transaction storage transaction = transactions[_txId];

        if (transaction.status != Status.PENDING) {
            revert MultiSignWallet_TransactionNotPending();
        }

        transaction.confirmations += 1;

        if (transaction.confirmations >= numConfirmationsRequired) {

            transaction.status = Status.CONFIRMED;

            _removePendingTx(_txId);
            
        }
    }

    function _removePendingTx(uint _txId) internal {
    for (uint i = 0; i < pendingTransactions.length; i++) {
        if (pendingTransactions[i] == _txId) {
            pendingTransactions[i] = pendingTransactions[pendingTransactions.length - 1];
            pendingTransactions.pop();
            break;
        }
    }
}

    receive() external payable {}

    // Commented out functions for future reference
    // function cancelTx() external override { }
    // function addOwner() external override { }
    // function removeOwner() external override { }
}
