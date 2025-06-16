// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {PaymentRegistry} from "../src/PaymentRegistry.sol";
import {FeeProcessor} from "../src/FeeProcessor.sol";

/**
 * @title Deploy Script for Scrooge Protocol
 * @dev Deploys the PaymentRegistry and FeeProcessor contracts to various networks
 */
contract DeployScript is Script {
    /// @notice Fee recipient addresses per network
    mapping(uint256 => address) public feeRecipients;
    
    function setUp() public {
        // Mainnet and testnets - replace with actual addresses
        feeRecipients[1] = 0x742d35cC6634C0532925A3B8D6cd6C1dd8d80C1F; // Mainnet
        feeRecipients[11155111] = 0x742d35cC6634C0532925A3B8D6cd6C1dd8d80C1F; // Sepolia
        feeRecipients[42161] = 0x742d35cC6634C0532925A3B8D6cd6C1dd8d80C1F; // Arbitrum
        feeRecipients[421614] = 0x742d35cC6634C0532925A3B8D6cd6C1dd8d80C1F; // Arbitrum Sepolia
        feeRecipients[10] = 0x742d35cC6634C0532925A3B8D6cd6C1dd8d80C1F; // Optimism
        feeRecipients[11155420] = 0x742d35cC6634C0532925A3B8D6cd6C1dd8d80C1F; // Optimism Sepolia
        feeRecipients[137] = 0x742d35cC6634C0532925A3B8D6cd6C1dd8d80C1F; // Polygon
        feeRecipients[80002] = 0x742d35cC6634C0532925A3B8D6cd6C1dd8d80C1F; // Polygon Amoy
        feeRecipients[8453] = 0x742d35cC6634C0532925A3B8D6cd6C1dd8d80C1F; // Base
        feeRecipients[84532] = 0x742d35cC6634C0532925A3B8D6cd6C1dd8d80C1F; // Base Sepolia
    }

    function run() external {
        uint256 chainId = block.chainid;
        address feeRecipient = feeRecipients[chainId];
        
        if (feeRecipient == address(0)) revert("Fee recipient not configured for this chain");
        
        console.log("Deploying Scrooge Protocol to chain ID:", chainId);
        console.log("Fee recipient:", feeRecipient);
        
        vm.startBroadcast();
        
        // Deploy PaymentRegistry first
        PaymentRegistry registry = new PaymentRegistry();
        console.log("PaymentRegistry deployed at:", address(registry));
        
        // Deploy FeeProcessor with registry address
        FeeProcessor feeProcessor = new FeeProcessor(feeRecipient, address(registry));
        console.log("FeeProcessor deployed at:", address(feeProcessor));
        
        vm.stopBroadcast();
        
        console.log("Current fee:", feeProcessor.fee(), "basis points");
        console.log("Max fee:", feeProcessor.MAX_FEE(), "basis points");
        
        // Log deployment details for easy copy-paste to config
        console.log("\n=== Deployment Summary ===");
        console.log("Chain ID:", chainId);
        console.log("PaymentRegistry:", address(registry));
        console.log("FeeProcessor:", address(feeProcessor));
        console.log("Fee Recipient:", feeRecipient);
        console.log("=========================");
    }
}