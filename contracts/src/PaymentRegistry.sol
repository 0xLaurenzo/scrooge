// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PaymentRegistry
 * @dev Core payment handler for ERC20 transfers and request tracking
 * @notice Handles atomic payment processing without fees
 */
contract PaymentRegistry is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    /// @notice Mapping to track if a request has been paid
    mapping(bytes32 => bool) public requestPaid;
    
    /// @notice Mapping to track payment details
    mapping(bytes32 => PaymentDetails) public payments;
    
    struct PaymentDetails {
        address payer;
        address recipient;
        address token;
        uint256 amount;
        uint256 timestamp;
        string ipfsCID;
    }

    /// @notice Emitted when a payment is completed
    /// @param requestId Unique identifier derived from IPFS CID
    /// @param payer Address that made the payment
    /// @param recipient Address that received the payment
    /// @param token ERC20 token contract address
    /// @param amount Amount received by recipient
    /// @param ipfsCID IPFS content identifier for payment request data
    event PaymentCompleted(
        bytes32 indexed requestId,
        address indexed payer,
        address indexed recipient,
        address token,
        uint256 amount,
        string ipfsCID
    );
    
    /// @notice Thrown when payment has already been completed
    error PaymentAlreadyCompleted();
    
    /// @notice Thrown when invalid address is provided
    error InvalidAddress();
    
    /// @notice Thrown when payment amount is zero
    error InvalidAmount();

    /**
     * @notice Process a payment request
     * @dev Handles the actual token transfer and records the payment
     * @param ipfsCID IPFS content identifier containing payment request details
     * @param payer Address making the payment
     * @param recipient Address that should receive the payment
     * @param token ERC20 token contract address
     * @param amount Amount to transfer to recipient
     */
    function processPayment(
        string calldata ipfsCID,
        address payer,
        address recipient,
        address token,
        uint256 amount
    ) external nonReentrant {
        if (recipient == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        // Generate request ID from IPFS CID
        bytes32 requestId = generateRequestId(ipfsCID);
        
        // Check if already paid
        if (requestPaid[requestId]) revert PaymentAlreadyCompleted();

        // Transfer tokens from the calling contract to recipient
        // Note: The calling contract should have the tokens already
        IERC20(token).safeTransferFrom(msg.sender, recipient, amount);

        // Mark as paid and store payment details
        requestPaid[requestId] = true;
        payments[requestId] = PaymentDetails({
            payer: payer,
            recipient: recipient,
            token: token,
            amount: amount,
            timestamp: block.timestamp,
            ipfsCID: ipfsCID
        });

        emit PaymentCompleted(requestId, payer, recipient, token, amount, ipfsCID);
    }

    /**
     * @notice Generate request ID from IPFS CID
     * @param ipfsCID IPFS content identifier
     * @return requestId Unique identifier for the payment request
     */
    function generateRequestId(string calldata ipfsCID) public pure returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked(ipfsCID));
    }

    /**
     * @notice Check if a payment request has been completed
     * @param requestId Request identifier to check
     * @return paid Whether the request has been paid
     */
    function isRequestPaid(bytes32 requestId) external view returns (bool paid) {
        paid = requestPaid[requestId];
    }

    /**
     * @notice Get payment details for a request
     * @param requestId Request identifier
     * @return details Payment details struct
     */
    function getPaymentDetails(bytes32 requestId) external view returns (PaymentDetails memory details) {
        details = payments[requestId];
    }
}