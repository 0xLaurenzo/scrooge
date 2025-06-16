// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PaymentRegistry.sol";

/**
 * @title FeeProcessor
 * @dev Handles payment requests with automatic fee collection
 * @notice Wraps PaymentRegistry to add fee functionality
 */
contract FeeProcessor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Protocol fee in basis points (100 = 1%, 50 = 0.5%)
    uint256 public fee = 50; // 0.5%
    
    /// @notice Maximum fee that can be set (10%)
    uint256 public constant MAX_FEE = 1000;
    
    /// @notice Denominator for fee calculations (10,000 basis points = 100%)
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    /// @notice Address that receives protocol fees
    address public feeRecipient;
    
    /// @notice Payment registry contract
    PaymentRegistry public immutable REGISTRY;

    /// @notice Emitted when protocol fee is updated
    event FeeUpdated(uint256 oldFee, uint256 newFee);

    /// @notice Emitted when fee recipient is updated
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    /// @notice Emitted when a payment is processed with fees
    event PaymentProcessed(bytes32 indexed requestId, uint256 totalAmount, uint256 feeAmount);

    /// @notice Thrown when fee exceeds maximum allowed
    error FeeExceedsMaximum();
    
    /// @notice Thrown when invalid address is provided
    error InvalidAddress();
    
    /// @notice Thrown when payment amount is zero
    error InvalidAmount();

    /**
     * @dev Initialize the contract with fee recipient and registry
     * @param _feeRecipient Address that will receive protocol fees
     * @param _registry PaymentRegistry contract address
     */
    constructor(address _feeRecipient, address _registry) Ownable(msg.sender) {
        if (_feeRecipient == address(0)) revert InvalidAddress();
        if (_registry == address(0)) revert InvalidAddress();
        
        feeRecipient = _feeRecipient;
        REGISTRY = PaymentRegistry(_registry);
    }

    /**
     * @notice Process payment request with fee on top
     * @dev User approves this contract for amount + fee
     * @param ipfsCID IPFS content identifier containing payment request details
     * @param recipient Address that should receive the payment
     * @param token ERC20 token contract address
     * @param amount Amount that recipient will receive (fee will be added on top)
     */
    function payRequest(
        string calldata ipfsCID,
        address recipient,
        address token,
        uint256 amount
    ) external nonReentrant {
        if (recipient == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        // Calculate fee on top of the amount
        uint256 feeAmount = (amount * fee) / FEE_DENOMINATOR;
        uint256 totalAmount = amount + feeAmount;

        // Transfer total amount (payment + fee) from user to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), totalAmount);

        // Transfer fee to fee recipient
        if (feeAmount > 0) {
            IERC20(token).safeTransfer(feeRecipient, feeAmount);
        }

        // Approve registry to spend the full amount for recipient
        IERC20(token).forceApprove(address(REGISTRY), amount);

        // Call registry to process the payment
        REGISTRY.processPayment(
            ipfsCID,
            msg.sender, // original payer
            recipient,
            token,
            amount
        );

        // Generate request ID for event
        bytes32 requestId = REGISTRY.generateRequestId(ipfsCID);
        emit PaymentProcessed(requestId, totalAmount, feeAmount);
    }

    /**
     * @notice Update the protocol fee
     * @dev Only owner can call this function
     * @param newFee New fee in basis points (max 1000 = 10%)
     */
    function setFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert FeeExceedsMaximum();
        
        uint256 oldFee = fee;
        fee = newFee;
        
        emit FeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Update the fee recipient address
     * @dev Only owner can call this function
     * @param newFeeRecipient New address to receive protocol fees
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert InvalidAddress();
        
        address oldRecipient = feeRecipient;
        feeRecipient = newFeeRecipient;
        
        emit FeeRecipientUpdated(oldRecipient, newFeeRecipient);
    }

    /**
     * @notice Calculate fee amount for a given payment amount
     * @param amount Payment amount that recipient will receive
     * @return feeAmount Fee that will be charged on top
     * @return totalAmount Total amount user needs to pay (amount + fee)
     */
    function calculateFee(uint256 amount) external view returns (uint256 feeAmount, uint256 totalAmount) {
        feeAmount = (amount * fee) / FEE_DENOMINATOR;
        totalAmount = amount + feeAmount;
    }
}