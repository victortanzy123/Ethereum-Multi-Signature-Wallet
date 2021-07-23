// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

contract MultiSigWallet {
    /// Storage Variables:
    address[] public owners;
    uint256 public numberOfConfirmationsRequired;
    uint256 public txIndex;

    /// Mappings:
    mapping(address => bool) public isOwner;
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public hasConfirmed;

    /// Data structures:
    // Transaction Structure:
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint256 numberOfConfirmations;
        bool executed;
    }

    /// Events:

    // Depositing funds to Wallet:
    event DepositEvent(address indexed sender, uint256 amount, uint256 balance);

    // Submitting Transaction Event:
    event submitTransactionDetails(
        address indexed owner,
        address indexed to,
        uint256 value,
        bytes data,
        uint256 indexed txIndex
    );

    // Confirming Transaction:
    event confirmTransactionDetails(
        address indexed owner,
        uint256 indexed txIndex
    );

    // Execute Transaction:
    event executeTransactionDetails(
        address indexed owner,
        uint256 indexed txIndex
    );

    // Revoke Confirmation:
    event revokeConfirmationDetails(
        address indexed owner,
        uint256 indexed txIndex
    );

    /// Modifiers:

    // only Owner Authorization:
    modifier onlyOwner() {
        require(isOwner[msg.sender] == true, "Not owner");
        _;
    }

    // Validate Transaction is NOT Executed:
    modifier notExecuted(uint256 _txIndex) {
        require(
            transactions[_txIndex].executed == false,
            "Transaction has been executed already"
        );
        _;
    }

    // Validate Particular Address confirming has NOT done so:
    modifier notConfirmed(uint256 _txIndex) {
        require(
            hasConfirmed[_txIndex][msg.sender] == false,
            "already confirmed"
        );
        _;
    }

    constructor(
        address[] memory _ownersAddressArray,
        uint256 _numConfirmationsRequired
    ) {
        require(
            _ownersAddressArray.length > 0,
            "Insufficient number of owners"
        );
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _ownersAddressArray.length,
            "Invalid number of confirmations required"
        );

        // Validate none of the addreses are ZER0_ADDRESSES:
        for (uint256 i = 0; i < _ownersAddressArray.length; i++) {
            address _ownerToBeAdded = _ownersAddressArray[i];
            require(
                _ownerToBeAdded != address(0),
                "Address added cannot be the zero address"
            );

            // Add validated address as an owner of this wallet
            isOwner[_ownerToBeAdded] = true;
            owners.push(_ownerToBeAdded);
        }

        // Set the number of Confirmations Required:
        numberOfConfirmationsRequired = _numConfirmationsRequired;
    }

    /// Core Functions of the Multi-Sig Wallet:

    // 1.) Submitting a Transaction:
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        // Creating a new struct with nested mapping:
        Transaction storage newTransaction = transactions[txIndex];
        newTransaction.to = _to;
        newTransaction.value = _value;
        newTransaction.data = _data;
        newTransaction.numberOfConfirmations = 1;
        newTransaction.executed = false;
        // newTransaction.confirmedOwners.push(msg.sender);

        hasConfirmed[txIndex][msg.sender] = true;

        // Increment txIndex:
        txIndex++;

        // emit event:
        emit submitTransactionDetails(
            msg.sender,
            _to,
            _value,
            _data,
            txIndex - 1
        );
    }

    // 2.) Confirming Transaction:
    // Check for whether caller is an owner of this wallet, has NOT confirmed this transaction and this transaction has NOT been executed
    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        notConfirmed(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage specificTransaction = transactions[_txIndex];

        // Appending owner's approval to confirm the transaction:
        specificTransaction.numberOfConfirmations += 1;
        hasConfirmed[_txIndex][msg.sender] = true;
        // specificTransaction.confirmedOwners.push(msg.sender);

        // emit event:
        emit confirmTransactionDetails(msg.sender, _txIndex);
    }

    // 3.) Execute transaction:
    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        notExecuted(_txIndex)
    {
        Transaction storage specificPendingTransaction = transactions[_txIndex];

        require(
            specificPendingTransaction.numberOfConfirmations >=
                numberOfConfirmationsRequired,
            "Insufficient confirmations"
        );

        // Low-level function used to transaction:
        (bool success, ) = specificPendingTransaction.to.call{
            value: specificPendingTransaction.value
        }(specificPendingTransaction.data);
        require(success, "Transaction Failed");

        // emit Event:
        emit executeTransactionDetails(msg.sender, _txIndex);
    }

    // 4.) Revoke Confirmation:
    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        notExecuted(_txIndex)
    {
        require(
            hasConfirmed[_txIndex][msg.sender] == true,
            "owner has not yet confirmed"
        );

        Transaction storage specificPendingTransaction = transactions[_txIndex];

        // Update state:
        hasConfirmed[_txIndex][msg.sender] = false;

        // for (
        //     uint256 i;
        //     i < specificPendingTransaction.confirmedOwners.length;
        //     i++
        // ) {
        //     if (specificPendingTransaction.confirmedOwner[i] == msg.sender) {}
        // }

        // emit Event:
        revokeConfirmationDetails(msg.sender, _txIndex);
    }

    /// Helper Functions:

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionStatus(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            uint256 numberOfConfirmations,
            bool executed
        )
    {
        Transaction storage specificTransaction = transactions[_txIndex];

        return (
            specificTransaction.to,
            specificTransaction.value,
            specificTransaction.data,
            specificTransaction.numberOfConfirmations,
            specificTransaction.executed
        );
    }

    function getTransactionCount() public view returns (uint256) {
        return txIndex;
    }

    // Fallback Function:
    receive() external payable {
        // Emit event after receiving:
        emit DepositEvent(msg.sender, msg.value, address(this).balance);
    }
}
