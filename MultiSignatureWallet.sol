// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSignatureWallet {

    event TransactionCreated(address creator, address to, uint amount, uint transactionId);
    event TransactionRemoved(address creator, address to, uint amount, uint transactionId);
    event TransactionOccured(address creator, address to, uint amount, uint transactionId);

    address public immutable owner;

    uint public immutable MIN_SIGNATURES_FOR_APPROVAL;
    
    mapping (address => bool) private operators;

    struct Transaction {
        uint amount;
        address to;
        uint signatureCount;
    }

    uint private transactionIdIncrementer;

    uint[] private pendingTransactions;
    mapping (uint => Transaction) private transactions;
    mapping (uint => mapping (address => bool)) private transactionSignatures;

    constructor(uint _minSignaturesForApproval) {
        MIN_SIGNATURES_FOR_APPROVAL = _minSignaturesForApproval;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "must be the owner");
        _;
    }

    modifier onlyOperators() {
        require(operators[msg.sender] || msg.sender == owner, "must be an operator");
        _;
    }

    function addOperator(address _operator) external {
        operators[_operator] = true;
    }

    function removeOperator(address _operator) external onlyOwner() {
        operators[_operator] = false;
    }

    function deposit() external payable {}

    function createTransaction(address _to, uint _amount) external onlyOwner() {

        require(address(this).balance >= _amount);

        Transaction memory newTransaction;
        newTransaction.to = _to;
        newTransaction.amount = _amount;
        newTransaction.signatureCount = 1;
        transactions[transactionIdIncrementer] = newTransaction;
        pendingTransactions.push(transactionIdIncrementer);

        transactionIdIncrementer++;

        emit TransactionCreated(msg.sender, _to, _amount, transactionIdIncrementer - 1);
    }

    function signTransaction(uint _transactionId) external onlyOperators() {
        _getTransactionIndexOrFail(_transactionId);
        _signTransaction(_transactionId);
        _checkHandleTransaction(_transactionId);
    }

    function _signTransaction(uint _transactionId) private onlyOperators() {

        require(!transactionSignatures[_transactionId][msg.sender], "already signed transaction");

        transactions[_transactionId].signatureCount++;
        transactionSignatures[_transactionId][msg.sender] = true;
    }

    function _checkHandleTransaction(uint _transactionId) private onlyOperators() {

        Transaction memory transaction = transactions[_transactionId];
        require(transaction.signatureCount >= MIN_SIGNATURES_FOR_APPROVAL);
        
        (bool success, ) = transaction.to.call{value: address(this).balance}("");

        if (success) {
            emit TransactionOccured(msg.sender, transaction.to, transaction.amount, _transactionId);
            _removeTransaction(_transactionId);
        }
    }

    function removeTransaction(uint _transactionId) external onlyOwner() {
        (Transaction memory deletedTransaction, uint deletedTransactionId) = _removeTransaction(_transactionId);
        emit TransactionRemoved(msg.sender, deletedTransaction.to, deletedTransaction.amount, deletedTransactionId);
    }

    function _removeTransaction(uint _transactionId) private onlyOperators() returns(Transaction memory, uint) {
        uint _removeIndex = _getTransactionIndexOrFail(_transactionId);
        uint deletedTransactionId = pendingTransactions[_removeIndex];
        Transaction memory deletedTransaction = transactions[deletedTransactionId];
        pendingTransactions[_removeIndex] = pendingTransactions[pendingTransactions.length - 1];
        pendingTransactions.pop();
        delete transactions[deletedTransactionId];
        return (deletedTransaction, deletedTransactionId);
    }

    function _getTransactionIndexOrFail(uint _transactionId) private view returns(uint) {
        for (uint i = 0; i < pendingTransactions.length; i++) {
            if (pendingTransactions[i] == _transactionId) {
                return i;
            }
        }
        revert("transaction does not exist");
    }

    fallback() external payable {}
    receive() external payable {}
}

