// Shared types for Scrooge protocol

export interface IPFSPaymentRequest {
  version: '1.0';
  createdAt: number;           // Unix timestamp
  creator: string;             // Creator wallet address  
  recipient: string;           // Payment recipient address
  chainId: number;             // Network chain ID
  token: {
    address: string;           // ERC20 token contract
    symbol: string;            // Token symbol
    decimals: number;          // Token decimals
    name: string;              // Token name
  };
  amount?: string;             // Fixed amount in wei (optional)
  description?: string;        // Payment description
  expiresAt?: number;          // Expiry timestamp (optional)
  metadata?: Record<string, any>; // Extensible metadata
}

export interface CachedPaymentRequest {
  id: string;                  // Generated from IPFS CID
  ipfsCID: string;            // IPFS content identifier
  createdBy: string;          // Creator wallet (indexed)
  recipientAddress: string;    // Recipient (for search)
  chainId: number;            // Network (indexed)
  tokenSymbol: string;        // For filtering
  amount?: string;            // For filtering
  createdAt: Date;           // For sorting
  expiresAt?: Date;          // For expiry checks
  
  // Payment tracking (updated from blockchain events)
  status: 'pending' | 'paid' | 'expired';
  paidBy?: string;           // Payer wallet address
  transactionHash?: string;   // Payment transaction
  paidAt?: Date;             // Payment timestamp
  blockNumber?: bigint;      // For event tracking
  
  // Cached IPFS data for performance
  cachedData: IPFSPaymentRequest;
}

export interface TokenInfo {
  address: string;
  symbol: string;
  decimals: number;
  name: string;
  logoURI?: string;
}

export interface ContractAddresses {
  [chainId: number]: string;
}

export type PaymentStatus = 'pending' | 'paid' | 'expired';