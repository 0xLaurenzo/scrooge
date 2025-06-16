// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {FeeProcessor} from "../src/FeeProcessor.sol";
import {PaymentRegistry} from "../src/PaymentRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1M tokens
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FeeProcessorTest is Test {
    FeeProcessor public feeProcessor;
    PaymentRegistry public registry;
    MockERC20 public token;
    
    address public owner = address(0x1);
    address public feeRecipient = address(0x2);
    address public payer = address(0x3);
    address public recipient = address(0x4);
    
    string public constant IPFS_CID = "QmTest123";
    uint256 public constant PAYMENT_AMOUNT = 1000 * 10**18; // 1000 tokens
    
    event PaymentProcessed(bytes32 indexed requestId, uint256 totalAmount, uint256 feeAmount);
    
    function setUp() public {
        vm.prank(owner);
        registry = new PaymentRegistry();
        
        vm.prank(owner);
        feeProcessor = new FeeProcessor(feeRecipient, address(registry));
        
        token = new MockERC20("Test Token", "TEST");
        
        // Give payer some tokens
        token.mint(payer, PAYMENT_AMOUNT * 10);
    }
    
    function testInitialState() public view {
        assertEq(feeProcessor.owner(), owner);
        assertEq(feeProcessor.feeRecipient(), feeRecipient);
        assertEq(feeProcessor.fee(), 50); // 0.5%
        assertEq(feeProcessor.MAX_FEE(), 1000); // 10%
        assertEq(feeProcessor.FEE_DENOMINATOR(), 10000);
        assertEq(address(feeProcessor.REGISTRY()), address(registry));
    }
    
    function testPayRequest() public {
        // Calculate expected amounts
        (uint256 expectedFee, uint256 expectedTotalAmount) = feeProcessor.calculateFee(PAYMENT_AMOUNT);
        
        // Approve tokens to fee processor (total amount = payment + fee)
        vm.prank(payer);
        token.approve(address(feeProcessor), expectedTotalAmount);
        
        // Get initial balances
        uint256 initialPayerBalance = token.balanceOf(payer);
        uint256 initialRecipientBalance = token.balanceOf(recipient);
        uint256 initialFeeRecipientBalance = token.balanceOf(feeRecipient);
        
        // Generate expected request ID
        bytes32 expectedRequestId = registry.generateRequestId(IPFS_CID);
        
        // Expect events
        vm.expectEmit(true, true, true, true);
        emit PaymentProcessed(expectedRequestId, expectedTotalAmount, expectedFee);
        
        // Make payment through fee processor
        vm.prank(payer);
        feeProcessor.payRequest(IPFS_CID, recipient, address(token), PAYMENT_AMOUNT);
        
        // Check balances: payer pays total amount, recipient gets full requested amount
        assertEq(token.balanceOf(payer), initialPayerBalance - expectedTotalAmount);
        assertEq(token.balanceOf(recipient), initialRecipientBalance + PAYMENT_AMOUNT);
        assertEq(token.balanceOf(feeRecipient), initialFeeRecipientBalance + expectedFee);
        
        // Check registry state
        assertTrue(registry.isRequestPaid(expectedRequestId));
        
        PaymentRegistry.PaymentDetails memory details = registry.getPaymentDetails(expectedRequestId);
        assertEq(details.payer, payer);
        assertEq(details.recipient, recipient);
        assertEq(details.token, address(token));
        assertEq(details.amount, PAYMENT_AMOUNT); // Registry records the recipient amount
        assertEq(details.ipfsCID, IPFS_CID);
    }
    
    function testPayRequestWithZeroFee() public {
        // Set fee to 0
        vm.prank(owner);
        feeProcessor.setFee(0);
        
        // With zero fee, total amount equals payment amount
        vm.prank(payer);
        token.approve(address(feeProcessor), PAYMENT_AMOUNT);
        
        // Get initial balances
        uint256 initialFeeRecipientBalance = token.balanceOf(feeRecipient);
        uint256 initialPayerBalance = token.balanceOf(payer);
        
        // Make payment
        vm.prank(payer);
        feeProcessor.payRequest(IPFS_CID, recipient, address(token), PAYMENT_AMOUNT);
        
        // Check that recipient receives full amount and no fee is collected
        assertEq(token.balanceOf(recipient), PAYMENT_AMOUNT);
        assertEq(token.balanceOf(feeRecipient), initialFeeRecipientBalance); // No change
        assertEq(token.balanceOf(payer), initialPayerBalance - PAYMENT_AMOUNT); // Payer pays exactly the amount
    }
    
    function testFailPayRequestAlreadyPaid() public {
        // Calculate total amount needed for both payments
        (, uint256 totalAmount) = feeProcessor.calculateFee(PAYMENT_AMOUNT);
        
        // Approve tokens for two payments
        vm.prank(payer);
        token.approve(address(feeProcessor), totalAmount * 2);
        
        // Make first payment
        vm.prank(payer);
        feeProcessor.payRequest(IPFS_CID, recipient, address(token), PAYMENT_AMOUNT);
        
        // Try to pay again - should fail (registry will revert)
        vm.prank(payer);
        feeProcessor.payRequest(IPFS_CID, recipient, address(token), PAYMENT_AMOUNT);
    }
    
    function testFailPayRequestInvalidRecipient() public {
        (, uint256 totalAmount) = feeProcessor.calculateFee(PAYMENT_AMOUNT);
        
        vm.prank(payer);
        token.approve(address(feeProcessor), totalAmount);
        
        vm.prank(payer);
        feeProcessor.payRequest(IPFS_CID, address(0), address(token), PAYMENT_AMOUNT);
    }
    
    function testFailPayRequestZeroAmount() public {
        (, uint256 totalAmount) = feeProcessor.calculateFee(PAYMENT_AMOUNT);
        
        vm.prank(payer);
        token.approve(address(feeProcessor), totalAmount);
        
        vm.prank(payer);
        feeProcessor.payRequest(IPFS_CID, recipient, address(token), 0);
    }
    
    function testSetFee() public {
        uint256 newFee = 100; // 1%
        
        vm.expectEmit(true, true, true, true);
        emit FeeProcessor.FeeUpdated(50, newFee);
        
        vm.prank(owner);
        feeProcessor.setFee(newFee);
        
        assertEq(feeProcessor.fee(), newFee);
    }
    
    function testFailSetFeeExceedsMaximum() public {
        vm.prank(owner);
        feeProcessor.setFee(1001); // > 10%
    }
    
    function testSetFeeRecipient() public {
        address newFeeRecipient = address(0x5);
        
        vm.expectEmit(true, true, true, true);
        emit FeeProcessor.FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        
        vm.prank(owner);
        feeProcessor.setFeeRecipient(newFeeRecipient);
        
        assertEq(feeProcessor.feeRecipient(), newFeeRecipient);
    }
    
    function testCalculateFee() public view {
        (uint256 feeAmount, uint256 totalAmount) = feeProcessor.calculateFee(PAYMENT_AMOUNT);
        
        uint256 expectedFee = (PAYMENT_AMOUNT * 50) / 10000; // 0.5%
        uint256 expectedTotalAmount = PAYMENT_AMOUNT + expectedFee;
        
        assertEq(feeAmount, expectedFee);
        assertEq(totalAmount, expectedTotalAmount);
    }
    
    function testIntegrationFlow() public {
        // This test verifies the complete flow:
        // 1. User approves fee processor for total amount (payment + fee)
        // 2. Fee processor takes total amount from user
        // 3. Fee processor sends fee to fee recipient
        // 4. Fee processor calls registry to complete payment to recipient
        
        (uint256 expectedFee, uint256 totalAmount) = feeProcessor.calculateFee(PAYMENT_AMOUNT);
        
        vm.prank(payer);
        token.approve(address(feeProcessor), totalAmount);
        
        bytes32 requestId = registry.generateRequestId(IPFS_CID);
        
        // Initially not paid
        assertFalse(registry.isRequestPaid(requestId));
        
        // Make payment
        vm.prank(payer);
        feeProcessor.payRequest(IPFS_CID, recipient, address(token), PAYMENT_AMOUNT);
        
        // Now should be marked as paid in registry
        assertTrue(registry.isRequestPaid(requestId));
        
        // Verify fee was collected and recipient got full amount
        assertEq(token.balanceOf(feeRecipient), expectedFee);
        assertEq(token.balanceOf(recipient), PAYMENT_AMOUNT);
    }
    
    function testMultiplePaymentsWithDifferentCIDs() public {
        string memory cid1 = "QmTest1";
        string memory cid2 = "QmTest2";
        
        (uint256 feeAmount, uint256 totalAmount) = feeProcessor.calculateFee(PAYMENT_AMOUNT);
        
        vm.startPrank(payer);
        token.approve(address(feeProcessor), totalAmount * 2);
        
        feeProcessor.payRequest(cid1, recipient, address(token), PAYMENT_AMOUNT);
        feeProcessor.payRequest(cid2, recipient, address(token), PAYMENT_AMOUNT);
        
        vm.stopPrank();
        
        // Both requests should be marked as paid
        assertTrue(registry.isRequestPaid(registry.generateRequestId(cid1)));
        assertTrue(registry.isRequestPaid(registry.generateRequestId(cid2)));
        
        // Check total amounts received: recipient gets full amount * 2, fee recipient gets fee * 2
        assertEq(token.balanceOf(recipient), PAYMENT_AMOUNT * 2);
        assertEq(token.balanceOf(feeRecipient), feeAmount * 2);
    }
}