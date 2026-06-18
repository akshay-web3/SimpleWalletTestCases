// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract SimpleWallet {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error InvalidAddress();
    error InvalidAmount();
    error InsufficientBalance();
    error EmergencyActive();
    error EmergencyNotActive();
    error StartTimeNotReached();
    error SuspiciousActivityDetected();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Transaction {
        address sender;
        address receiver;
        uint256 timestamp;
        uint256 amount;
    }

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    address public walletOwner;
    bool public emergencyMode;

    mapping(address => uint256) public suspiciousActivityCount;

    Transaction[] private transactions;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event FundsDeposited(
        address indexed sender,
        uint256 amount
    );

    event FundsTransferred(
        address indexed receiver,
        uint256 amount
    );

    event FundsWithdrawn(
        address indexed receiver,
        uint256 amount
    );

    event UserPaymentReceived(
        address indexed sender,
        address indexed receiver,
        uint256 amount
    );

    event EmergencyModeUpdated(bool isEnabled);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        walletOwner = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != walletOwner) {
            revert Unauthorized();
        }
        _;
    }

    modifier whenNotInEmergency() {
        if (emergencyMode) {
            revert EmergencyActive();
        }
        _;
    }

    modifier notSuspicious(address user) {
        if (suspiciousActivityCount[user] >= 5) {
            revert SuspiciousActivityDetected();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function toggleEmergencyMode() external onlyOwner {
        emergencyMode = !emergencyMode;
        emit EmergencyModeUpdated(emergencyMode);
    }

    function changeOwner(address newOwner) external onlyOwner whenNotInEmergency {
        if (newOwner == address(0)) {
            revert InvalidAddress();
        }
    
        address previousOwner = walletOwner;
        walletOwner = newOwner;

        emit OwnershipTransferred(
            previousOwner,
            newOwner
        );
    }

    function transferFromContract(address payable recipient,uint256 amountInWei)external onlyOwner whenNotInEmergency{
        if (recipient == address(0)) {
            revert InvalidAddress();
        }

        if (address(this).balance < amountInWei) {
            revert InsufficientBalance();
        }

        (bool success, ) = recipient.call{value: amountInWei}("");

        if (!success) {
            revert TransferFailed();
        }

        _recordTransaction(address(this),recipient,amountInWei);

        emit FundsTransferred(recipient,amountInWei);
    }

    function withdrawContractFunds(uint256 amountInWei) external onlyOwner{
        if (address(this).balance < amountInWei) {
            revert InsufficientBalance();
        }

        (bool success, ) = payable(walletOwner).call{value: amountInWei}("");

        if (!success) {
            revert TransferFailed();
        }

        _recordTransaction(address(this),walletOwner,amountInWei);

        emit FundsWithdrawn(walletOwner,amountInWei);
    }

    function emergencyWithdrawal() external onlyOwner{
        if (!emergencyMode) {
            revert EmergencyNotActive();
        }

        uint256 contractBalance = address(this).balance;

        (bool success, ) = payable(walletOwner).call{value: contractBalance}("");

        if (!success) {
            revert TransferFailed();
        }

        _recordTransaction(address(this),walletOwner,contractBalance);

        emit FundsWithdrawn(walletOwner,contractBalance);
    }

    /*//////////////////////////////////////////////////////////////
                          USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositToContract(uint256 startTime) external payable notSuspicious(msg.sender) whenNotInEmergency
    {
        if (block.timestamp <= startTime) {
            revert StartTimeNotReached();
        }

        if (msg.value == 0) {
            revert InvalidAmount();
        }

        _recordTransaction(msg.sender,address(this),msg.value);

        emit FundsDeposited(msg.sender, msg.value);
    }

    function transferDirectlyToUser(
        address payable recipient
    )
        external
        payable
        whenNotInEmergency
    {
        if (recipient == address(0)) {
            revert InvalidAddress();
        }

        if (msg.value == 0) {
            revert InvalidAmount();
        }

        (bool success, ) = recipient.call{
            value: msg.value
        }("");

        if (!success) {
            revert TransferFailed();
        }

        _recordTransaction(
            msg.sender,
            recipient,
            msg.value
        );

        emit FundsTransferred(
            recipient,
            msg.value
        );
    }

    function sendFundsToOwner()
        external
        payable
        whenNotInEmergency
    {
        if (msg.value == 0) {
            revert InvalidAmount();
        }

        (bool success, ) = payable(walletOwner).call{
            value: msg.value
        }("");

        if (!success) {
            revert TransferFailed();
        }

        _recordTransaction(
            msg.sender,
            walletOwner,
            msg.value
        );

        emit UserPaymentReceived(
            msg.sender,
            walletOwner,
            msg.value
        );
    }

    /*//////////////////////////////////////////////////////////////
                         SUSPICIOUS ACTIVITY
    //////////////////////////////////////////////////////////////*/

    function _reportSuspiciousActivity(
        address user
    )
        internal
    {
        unchecked {
            suspiciousActivityCount[user]++;
        }
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getContractBalanceInWei()
        external
        view
        returns (uint256)
    {
        return address(this).balance;
    }

    function getOwnerBalanceInWei()
        external
        view
        returns (uint256)
    {
        return walletOwner.balance;
    }

    function getTransactionHistory()
        external
        view
        returns (Transaction[] memory)
    {
        return transactions;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _recordTransaction(
        address sender,
        address receiver,
        uint256 amount
    )
        internal
    {
        transactions.push(
            Transaction({
                sender: sender,
                receiver: receiver,
                timestamp: block.timestamp,
                amount: amount
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                        RECEIVE & FALLBACK
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        _recordTransaction(
            msg.sender,
            address(this),
            msg.value
        );

        emit FundsDeposited(
            msg.sender,
            msg.value
        );
    }

    fallback() external payable {
        _reportSuspiciousActivity(msg.sender);
    }
}