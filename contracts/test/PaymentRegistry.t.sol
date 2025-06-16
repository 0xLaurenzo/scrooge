// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
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

contract PaymentRegistryTest is Test {
    PaymentRegistry public registry;
    MockERC20 public token;
    
    address public payer = address(0x1);
    address public recipient = address(0x2);
    address public caller = address(0x3); // Simulates the fee processor
    
    string public constant IPFS_CID = "QmTest123";
    uint256 public constant AMOUNT = 1000 * 10**18;
    
    event PaymentCompleted(
        bytes32 indexed requestId,
        address indexed payer,
        address indexed recipient,
        address token,
        uint256 amount,
        string ipfsCID
    );
    
    function setUp() public {
        registry = new PaymentRegistry();
        token = new MockERC20("Test Token", "TEST");
        
        // Give caller (simulating fee processor) some tokens
        token.mint(caller, AMOUNT * 10);
        
        // Caller approves registry to spend its tokens
        vm.prank(caller);
        token.approve(address(registry), AMOUNT * 10);
    }
    
    function testProcessPayment() public {
        bytes32 requestId = registry.generateRequestId(IPFS_CID);
        
        // Get initial balances
        uint256 initialCallerBalance = token.balanceOf(caller);
        uint256 initialRecipientBalance = token.balanceOf(recipient);
        
        // Expect event
        vm.expectEmit(true, true, true, true);
        emit PaymentCompleted(requestId, payer, recipient, address(token), AMOUNT, IPFS_CID);
        
        // Process payment as the caller (fee processor)
        vm.prank(caller);
        registry.processPayment(IPFS_CID, payer, recipient, address(token), AMOUNT);
        
        // Check balances
        assertEq(token.balanceOf(caller), initialCallerBalance - AMOUNT);
        assertEq(token.balanceOf(recipient), initialRecipientBalance + AMOUNT);
        
        // Check payment recorded
        assertTrue(registry.requestPaid(requestId));
        
        PaymentRegistry.PaymentDetails memory details = registry.getPaymentDetails(requestId);
        assertEq(details.payer, payer);
        assertEq(details.recipient, recipient);
        assertEq(details.token, address(token));
        assertEq(details.amount, AMOUNT);
        assertEq(details.ipfsCID, IPFS_CID);
        assertEq(details.timestamp, block.timestamp);
    }
    
    function testFailProcessPaymentAlreadyPaid() public {
        // Process first payment
        vm.prank(caller);
        registry.processPayment(IPFS_CID, payer, recipient, address(token), AMOUNT);
        
        // Try to process again - should fail
        vm.prank(caller);
        registry.processPayment(IPFS_CID, payer, recipient, address(token), AMOUNT);
    }
    
    function testFailProcessPaymentInvalidRecipient() public {
        vm.prank(caller);
        registry.processPayment(IPFS_CID, payer, address(0), address(token), AMOUNT);
    }
    
    function testFailProcessPaymentZeroAmount() public {
        vm.prank(caller);
        registry.processPayment(IPFS_CID, payer, recipient, address(token), 0);
    }
    
    function testGenerateRequestId() public view {
        bytes32 requestId = registry.generateRequestId(IPFS_CID);
        bytes32 expectedId = keccak256(abi.encodePacked(IPFS_CID));
        
        assertEq(requestId, expectedId);
    }
    
    function testIsRequestPaid() public {
        bytes32 requestId = registry.generateRequestId(IPFS_CID);
        
        assertFalse(registry.isRequestPaid(requestId));
        
        vm.prank(caller);
        registry.processPayment(IPFS_CID, payer, recipient, address(token), AMOUNT);
        
        assertTrue(registry.isRequestPaid(requestId));
    }
    
    function testMultiplePayments() public {
        string memory cid1 = "QmTest1";
        string memory cid2 = "QmTest2";
        
        vm.prank(caller);
        registry.processPayment(cid1, payer, recipient, address(token), AMOUNT);
        
        vm.prank(caller);
        registry.processPayment(cid2, payer, recipient, address(token), AMOUNT);
        
        assertTrue(registry.isRequestPaid(registry.generateRequestId(cid1)));
        assertTrue(registry.isRequestPaid(registry.generateRequestId(cid2)));
    }
    
    function testFailInsufficientAllowance() public {
        // Remove approval
        vm.prank(caller);
        token.approve(address(registry), 0);
        
        // Try to process payment - should fail due to no allowance
        vm.prank(caller);
        registry.processPayment(IPFS_CID, payer, recipient, address(token), AMOUNT);
    }
}