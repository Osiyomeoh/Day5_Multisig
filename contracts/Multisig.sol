//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Multisig {
    uint256 public quorum;
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public transactionCount;
    mapping(uint256 => Transaction) public transactions;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
        mapping(address => bool) isConfirmed;  
    }

    constructor(uint256 _quorum, address[] memory _owners) {
        require(_quorum > 0 && _quorum <= _owners.length, "Invalid quorum");
        quorum = _quorum;
        owners = _owners;
        for (uint i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
    }

    function addFunds() public payable {
        require(msg.value > 0, "Amount must be greater than 0");
        
    }

    function createTransaction(address _to, uint256 _value, bytes memory _data) public {
        require(isOwner[msg.sender], "Only owners can create transactions");
        transactionCount++;
        Transaction storage newTransaction = transactions[transactionCount];
        newTransaction.to = _to;
        newTransaction.value = _value;
        newTransaction.data = _data;
        newTransaction.executed = false;
        newTransaction.confirmationCount = 0;
        emit TransactionCreated(transactionCount, msg.sender, _to, _value, _data);
    }

    function confirmTransaction(uint256 transactionId) public {
        require(isOwner[msg.sender], "Only owners can confirm transactions");
        Transaction storage transaction = transactions[transactionId];
        require(transaction.executed == false, "Transaction already executed");
        require(!transaction.isConfirmed[msg.sender], "Transaction already confirmed by this owner");
        
        transaction.isConfirmed[msg.sender] = true;
        transaction.confirmationCount++;
        
        emit TransactionConfirmed(transactionId, msg.sender);
    }

    function revokeConfirmation(uint256 transactionId) public {
        require(isOwner[msg.sender], "Only owners can revoke confirmations");
        Transaction storage transaction = transactions[transactionId];
        require(transaction.executed == false, "Transaction already executed");
        require(transaction.isConfirmed[msg.sender], "Transaction not confirmed by this owner");
        
        transaction.isConfirmed[msg.sender] = false;
        transaction.confirmationCount--;
        
        emit ConfirmationRevoked(transactionId, msg.sender);
    }

    function executeTransaction(uint256 transactionId) public {
        require(isOwner[msg.sender], "Only owners can execute transactions");
        Transaction storage transaction = transactions[transactionId];
        require(transaction.executed == false, "Transaction already executed");
        require(transaction.confirmationCount >= quorum, "Quorum not reached");
        
        transaction.executed = true;
        emit TransactionExecuted(transactionId);

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction execution failed");
    }

    function withdraw(address payable _to, uint256 _amount) public {
        require(isOwner[msg.sender], "Only owners can withdraw funds");
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(_amount <= address(this).balance, "Insufficient balance");

        // Create a new transaction for the withdrawal
        transactionCount++;
        Transaction storage newTransaction = transactions[transactionCount];
        newTransaction.to = _to;
        newTransaction.value = _amount;
        newTransaction.data = "";
        newTransaction.executed = false;
        newTransaction.confirmationCount = 0;

        emit TransactionCreated(transactionCount, msg.sender, _to, _amount, "");
        emit WithdrawalRequested(transactionCount, msg.sender, _to, _amount);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    event TransactionCreated(uint256 indexed transactionId, address indexed creator, address to, uint256 value, bytes data);
    event TransactionConfirmed(uint256 indexed transactionId, address indexed owner);
    event TransactionExecuted(uint256 indexed transactionId);
    event Deposit(address indexed sender, uint256 amount);
    event ConfirmationRevoked(uint256 indexed transactionId, address indexed owner);
    event WithdrawalRequested(uint256 indexed transactionId, address indexed requester, address to, uint256 amount);
}