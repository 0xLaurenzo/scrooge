# Scrooge - Payment Request App Design Document

## Overview

Scrooge is a decentralized crypto payment request application built on EVM-compatible blockchains. The app enables users to create, manage, and fulfill payment requests using ERC20 tokens through a simple web interface, with all payment request data stored on IPFS and payments handled through smart contracts.

### Key Architecture Principles

1. **No Wallet Required for Creation**: Users can create payment requests without connecting a wallet or signing transactions
2. **Decentralized Storage**: All payment request data is stored on IPFS, ensuring censorship resistance
3. **Smart Contract Payments**: Payments go through a smart contract that automatically collects protocol fees
4. **Event-Driven Updates**: Blockchain events update payment status, no manual webhooks needed
5. **Multi-Chain Support**: Same contract deployed across all supported EVM chains
6. **Minimal Database**: Supabase used only for caching/indexing, not as source of truth

## Architecture

### Technology Stack
- **Frontend**: SvelteKit 5 with TypeScript
- **Storage**: IPFS for payment request data (via Pinata/Infura)
- **Smart Contracts**: Solidity contracts for payment processing with built-in fees
- **Database**: Supabase (PostgreSQL for indexing and caching only)
- **Web3 Integration**: AppKit (Reown/WalletConnect) with Wagmi/Viem
- **Styling**: Tailwind CSS
- **Supported Networks**: Multi-chain EVM support (Mainnet, Arbitrum, Optimism, Polygon, Base + testnets)

### Decentralized Infrastructure
- IPFS for permanent, censorship-resistant storage of payment requests
- Smart contracts handle all payments with automatic fee collection
- Supabase serves as an indexing layer for performance and search
- Event-driven architecture monitors blockchain events
- AppKit configured for wallet connections and chain switching
- Multi-chain support with 15+ EVM networks

## User Flows

### 1. Payment Request Creation Flow

**User Story**: As a user, I want to create a payment request so that I can receive payments from others.

**Flow**:
1. User connects wallet via AppKit (for auto-filling address only)
2. User navigates to "Create Request" page
3. User fills out request form:
   - Recipient address (auto-filled from connected wallet)
   - Token selection (ERC20 token dropdown)
   - Amount (fixed amount or "allow payer to specify")
   - Description/memo (optional)
   - Expiry date (optional)
4. User submits form (NO TRANSACTION REQUIRED)
5. System:
   - Uploads request data to IPFS
   - Generates unique request ID from IPFS CID
   - Caches data in Supabase for indexing
   - Creates shareable link with IPFS CID
6. User receives confirmation with link to share

**Technical Requirements**:
- Form validation for addresses, amounts, token contracts
- IPFS upload via Pinata/Infura (no gas costs)
- Request data cached in Supabase for querying
- Client-side ID generation from IPFS CID
- Shareable link format: `/pay/[ipfsCID]`

### 2. Dashboard Flow

**User Story**: As a user, I want to view all my payment requests so that I can track their status.

**Flow**:
1. User connects wallet via AppKit
2. User navigates to dashboard
3. System displays all requests created by connected wallet address
4. User can filter/search requests by:
   - Status (pending, paid, expired)
   - Date range
   - Token type
   - Amount range
5. User can view request details
6. User can copy shareable links
7. User can cancel pending requests

**Technical Requirements**:
- Query Supabase cache filtered by creator wallet address
- Monitor blockchain events for payment status updates
- Real-time updates when contract emits PaymentCompleted events
- IPFS data retrieval for full request details
- Filtering and pagination using Supabase queries on cached data

### 3. Payment Fulfillment Flow

**User Story**: As a payer, I want to fulfill a payment request so that I can send the requested payment.

**Flow**:
1. Payer receives shareable link
2. Payer opens link (no wallet connection required initially)
3. System displays request details:
   - Recipient address
   - Requested token and amount
   - Description/memo
   - Status and expiry
4. Payer connects wallet via AppKit
5. System validates:
   - Payer has sufficient token balance
   - Request is still valid (not expired/already paid)
   - Correct network selected
6. Payer reviews transaction details
7. Payer approves token spending to smart contract
8. Payer confirms payment through smart contract (includes fee)
9. Contract transfers tokens and emits PaymentCompleted event
10. System monitors event and updates status
11. Both parties receive confirmation

**Technical Requirements**:
- Fetch request data from IPFS using CID from URL
- ERC20 balance checking via Wagmi hooks
- Two-step transaction process:
  1. ERC20 approve to smart contract
  2. Contract payRequest function call
- Event monitoring for PaymentCompleted events
- Update cached status in Supabase when events detected
- Network validation and switching prompts via AppKit

## Data Models

### Decentralized Data Architecture

```typescript
// Data stored on IPFS (immutable)
interface IPFSPaymentRequest {
  version: '1.0',
  createdAt: number,           // Unix timestamp
  creator: string,             // Creator wallet address  
  recipient: string,           // Payment recipient address
  chainId: number,             // Network chain ID
  token: {
    address: string,           // ERC20 token contract
    symbol: string,            // Token symbol
    decimals: number,          // Token decimals
    name: string              // Token name
  },
  amount?: string,             // Fixed amount in wei (optional)
  description?: string,        // Payment description
  expiresAt?: number,         // Expiry timestamp (optional)
  metadata?: Record<string, any> // Extensible metadata
}

// Data cached in Supabase (for indexing/querying)
interface CachedPaymentRequest {
  id: string,                  // Generated from IPFS CID
  ipfsCID: string,            // IPFS content identifier
  createdBy: string,          // Creator wallet (indexed)
  recipientAddress: string,    // Recipient (for search)
  chainId: number,            // Network (indexed)
  tokenSymbol: string,        // For filtering
  amount?: string,            // For filtering
  createdAt: Date,           // For sorting
  expiresAt?: Date,          // For expiry checks
  
  // Payment tracking (updated from blockchain events)
  status: 'pending' | 'paid' | 'expired',
  paidBy?: string,           // Payer wallet address
  transactionHash?: string,   // Payment transaction
  paidAt?: Date,             // Payment timestamp
  blockNumber?: bigint,      // For event tracking
  
  // Cached IPFS data for performance
  cachedData: IPFSPaymentRequest
}
```

## Technical Implementation Areas

### Pages/Routes Required
- `/` - Landing page with app overview
- `/create` - Payment request creation form (no wallet required)
- `/dashboard` - User dashboard for managing requests
- `/pay/[cid]` - Public payment page (IPFS CID in URL)
- `/pay/[cid]/success` - Payment confirmation page
- `/api/ipfs/[cid]` - IPFS gateway fallback

### Components Required
- `CreateRequestForm.svelte` - Request creation form
- `RequestCard.svelte` - Request display component
- `PaymentForm.svelte` - Payment execution form
- `TokenSelector.svelte` - ERC20 token selection
- `RequestStatus.svelte` - Status display component
- `TransactionMonitor.svelte` - Transaction status tracking

### Services Required
- `IPFSService` - Upload/retrieve payment requests from IPFS
- `RequestService` - Create requests (IPFS + cache), query cached data
- `ContractService` - Interact with ScroogePayments smart contract
- `TokenService` - ERC20 token information and balance checking
- `EventMonitorService` - Monitor blockchain for payment events
- `ValidationService` - Address, amount, and request validation

## Backend Architecture

### Decentralized Storage Architecture
- **Primary Storage**: IPFS for all payment request data
- **Smart Contracts**: Payment processing with automatic fees
- **Indexing Layer**: Supabase PostgreSQL for caching and queries
- **No Authentication Required**: Creating requests doesn't need wallet connection
- **Event Monitoring**: Blockchain event listeners for payment tracking

### Supabase Schema (Caching Layer Only)
```sql
-- Cached payment requests (indexing layer)
CREATE TABLE payment_requests_cache (
  id TEXT PRIMARY KEY, -- Generated from IPFS CID
  ipfs_cid TEXT UNIQUE NOT NULL,
  created_by TEXT NOT NULL, -- Creator wallet (indexed)
  recipient_address TEXT NOT NULL,
  chain_id INTEGER NOT NULL,
  token_symbol TEXT,
  amount TEXT, -- For filtering
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  
  -- Payment status (updated from blockchain events)
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'expired')),
  paid_by TEXT,
  transaction_hash TEXT,
  paid_at TIMESTAMPTZ,
  block_number BIGINT,
  
  -- Cached IPFS data for performance
  cached_data JSONB NOT NULL
);

-- Indexes for performance
CREATE INDEX idx_created_by ON payment_requests_cache(created_by);
CREATE INDEX idx_status ON payment_requests_cache(status);
CREATE INDEX idx_chain_id ON payment_requests_cache(chain_id);
CREATE INDEX idx_ipfs_cid ON payment_requests_cache(ipfs_cid);

-- No RLS needed - all data is public on IPFS anyway
-- This is just a performance cache
```

### Smart Contract Architecture

```solidity
contract ScroogePayments {
    uint256 public constant fee = 50; // 0.5% fee in basis points
    address public immutable feeRecipient;
    
    event PaymentCompleted(
        bytes32 indexed requestId,
        address indexed payer,
        address indexed recipient,
        address token,
        uint256 amount,
        uint256 feeAmount,
        string ipfsCID
    );
    
    constructor(address _feeRecipient) {
        feeRecipient = _feeRecipient;
    }
    
    function payRequest(
        string calldata ipfsCID,
        address recipient,
        address token,
        uint256 amount
    ) external {
        bytes32 requestId = keccak256(abi.encodePacked(ipfsCID));
        
        uint256 feeAmount = (amount * fee) / 10000;
        uint256 recipientAmount = amount - feeAmount;
        
        // Transfer tokens
        IERC20(token).transferFrom(msg.sender, recipient, recipientAmount);
        if (feeAmount > 0) {
            IERC20(token).transferFrom(msg.sender, feeRecipient, feeAmount);
        }
        
        emit PaymentCompleted(
            requestId,
            msg.sender,
            recipient,
            token,
            recipientAmount,
            feeAmount,
            ipfsCID
        );
    }
}
```

### Supabase Edge Functions

1. **cache-payment-request**
   - Caches IPFS data after upload
   - No authentication required
   - Returns success confirmation

2. **get-user-requests**
   - Queries cached requests by wallet
   - Returns paginated results
   - Supports filtering

3. **update-payment-status**
   - Called by event monitor
   - Updates cached payment status
   - No direct user access

### Event Monitoring Strategy

1. **Multi-Chain Event Monitoring**
   ```typescript
   class EventMonitorService {
     async monitorPaymentEvents(chainId: number) {
       const client = getPublicClient({ chainId });
       
       // Watch for PaymentCompleted events
       const unwatch = client.watchContractEvent({
         address: CONTRACTS[chainId],
         abi: ScroogePaymentsABI,
         eventName: 'PaymentCompleted',
         onLogs: (logs) => this.handlePaymentEvents(logs, chainId)
       });
     }
     
     async handlePaymentEvents(logs: Log[], chainId: number) {
       for (const log of logs) {
         const { requestId, payer, ipfsCID } = log.args;
         
         // Update cache in Supabase
         await supabase
           .from('payment_requests_cache')
           .update({
             status: 'paid',
             paid_by: payer,
             transaction_hash: log.transactionHash,
             block_number: log.blockNumber,
             paid_at: new Date()
           })
           .eq('id', requestId);
       }
     }
   }
   ```

2. **Frontend Transaction Monitoring**
   - Uses Wagmi's `waitForTransactionReceipt`
   - Provides immediate feedback
   - Updates UI optimistically

### IPFS Integration

```typescript
class IPFSService {
  private pinataJWT: string;
  private gateway: string = 'https://gateway.pinata.cloud/ipfs/';
  
  async uploadRequest(data: IPFSPaymentRequest): Promise<string> {
    const response = await fetch('https://api.pinata.cloud/pinning/pinJSONToIPFS', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.pinataJWT}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        pinataContent: data,
        pinataOptions: {
          cidVersion: 1
        },
        pinataMetadata: {
          name: `payment-request-${data.recipient}-${Date.now()}`
        }
      })
    });
    
    const result = await response.json();
    return result.IpfsHash;
  }
  
  async retrieveRequest(cid: string): Promise<IPFSPaymentRequest> {
    // Try multiple gateways for reliability
    const gateways = [
      `https://gateway.pinata.cloud/ipfs/${cid}`,
      `https://ipfs.io/ipfs/${cid}`,
      `https://cloudflare-ipfs.com/ipfs/${cid}`
    ];
    
    for (const gateway of gateways) {
      try {
        const response = await fetch(gateway, { 
          signal: AbortSignal.timeout(5000) 
        });
        if (response.ok) {
          return await response.json();
        }
      } catch (error) {
        continue; // Try next gateway
      }
    }
    
    throw new Error('Failed to retrieve from IPFS');
  }
}
```

### Request Creation Service (No Transaction)

```typescript
class RequestService {
  async createRequest(formData: CreateRequestInput): Promise<{ cid: string, shareUrl: string }> {
    // 1. Prepare IPFS data
    const ipfsData: IPFSPaymentRequest = {
      version: '1.0',
      createdAt: Date.now(),
      creator: formData.creatorAddress || 'anonymous',
      recipient: formData.recipientAddress,
      chainId: formData.chainId,
      token: {
        address: formData.tokenAddress,
        symbol: formData.tokenSymbol,
        decimals: formData.tokenDecimals,
        name: formData.tokenName
      },
      amount: formData.amount,
      description: formData.description,
      expiresAt: formData.expiresAt?.getTime()
    };
    
    // 2. Upload to IPFS (no blockchain transaction)
    const cid = await ipfsService.uploadRequest(ipfsData);
    
    // 3. Cache in Supabase for indexing
    const requestId = generateIdFromCID(cid);
    await supabase.from('payment_requests_cache').insert({
      id: requestId,
      ipfs_cid: cid,
      created_by: ipfsData.creator,
      recipient_address: ipfsData.recipient,
      chain_id: ipfsData.chainId,
      token_symbol: ipfsData.token.symbol,
      amount: ipfsData.amount,
      created_at: new Date(ipfsData.createdAt),
      expires_at: ipfsData.expiresAt ? new Date(ipfsData.expiresAt) : null,
      status: 'pending',
      cached_data: ipfsData
    });
    
    // 4. Return shareable link
    const shareUrl = `${window.location.origin}/pay/${cid}`;
    return { cid, shareUrl };
  }
}
```

### Contract Deployment Strategy

```typescript
// Contract addresses per chain
const SCROOGE_CONTRACTS: Record<number, Address> = {
  1: '0x...', // Mainnet
  42161: '0x...', // Arbitrum
  10: '0x...', // Optimism
  137: '0x...', // Polygon
  8453: '0x...', // Base
  // Testnets
  11155111: '0x...', // Sepolia
  421614: '0x...', // Arbitrum Sepolia
  // ... other chains
};

// Same contract deployed on each chain
// Fee recipient can be same address across chains
// Or use a multi-sig for each chain
```

## Areas Requiring Additional Specification

## Token Support Strategy

### Phase 1: ERC20 Transfer Support (PoC)

**Token List Sources:**
1. **Primary**: [Uniswap Default Token List](https://gateway.ipfs.io/ipns/tokens.uniswap.org)
   - Well-maintained, standardized format
   - Covers major tokens across all supported chains
   - Includes token metadata (name, symbol, decimals, logo)
   - ~400 verified tokens across multiple chains

2. **Fallback**: Hardcoded Core Tokens
   - Essential stablecoins and wrapped native tokens per chain
   - Guarantees availability even if primary source fails
   - Minimal set for reliability:
     ```typescript
     const FALLBACK_TOKENS = {
       // Mainnet
       1: [
         { symbol: 'USDC', address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', decimals: 6 },
         { symbol: 'USDT', address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', decimals: 6 },
         { symbol: 'DAI', address: '0x6B175474E89094C44Da98b954EedeAC495271d0F', decimals: 18 },
         { symbol: 'WETH', address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', decimals: 18 }
       ],
       // Arbitrum
       42161: [
         { symbol: 'USDC', address: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', decimals: 6 },
         { symbol: 'USDT', address: '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9', decimals: 6 },
         { symbol: 'DAI', address: '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1', decimals: 18 },
         { symbol: 'WETH', address: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', decimals: 18 }
       ],
       // ... other chains
     }
     ```

**Implementation Approach:**
```typescript
// Token service implementation
class TokenService {
  private cachedTokens: Map<number, Token[]> = new Map()
  
  async getTokensForChain(chainId: number): Promise<Token[]> {
    try {
      // 1. Check cache first
      if (this.cachedTokens.has(chainId)) {
        return this.cachedTokens.get(chainId)!
      }
      
      // 2. Try to fetch from Supabase (cached Uniswap list)
      const supabaseTokens = await this.fetchFromSupabase(chainId)
      if (supabaseTokens.length > 0) {
        this.cachedTokens.set(chainId, supabaseTokens)
        return supabaseTokens
      }
      
      // 3. Fall back to hardcoded tokens
      return FALLBACK_TOKENS[chainId] || []
    } catch (error) {
      // Always return fallback tokens on error
      return FALLBACK_TOKENS[chainId] || []
    }
  }
}

// Database schema remains the same
CREATE TABLE supported_tokens (
  address TEXT NOT NULL,
  chain_id INTEGER NOT NULL,
  symbol TEXT NOT NULL,
  name TEXT NOT NULL,
  decimals INTEGER NOT NULL,
  logo_uri TEXT,
  is_active BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (address, chain_id)
);
```

**Token List Refresh Strategy (PoC):**
- Manual refresh via admin command for POC
- Fetch Uniswap list and update Supabase cache
- Can be automated with scheduled Edge Function post-POC

### Phase 2: Swap Integration (Future)

**Architecture for Swaps:**
1. **Aggregator Integration**
   - 1inch Fusion API for best rates
   - LiFi for cross-chain swaps
   - 0x API as fallback

2. **Payment Request Enhancement:**
   ```typescript
   interface PaymentRequestV2 {
     // ... existing fields
     acceptedTokens?: string[]  // Multiple acceptable tokens
     preferredToken: string     // Primary requested token
     allowSwaps: boolean        // Enable swap functionality
   }
   ```

3. **Swap Flow:**
   - Payer selects payment token
   - System fetches swap quotes if needed
   - Display swap rate and fees
   - Execute swap + transfer in one transaction (using aggregator)

### Phase 3: Cross-Chain Support (Future)

**Cross-Chain Architecture:**
1. **Bridge Aggregator**: LiFi or Socket
2. **Payment Flow:**
   - Request specifies destination chain
   - Payer on different chain gets bridge quote
   - Single transaction bridges + pays
   - Webhook monitors destination chain

**Database Updates for Cross-Chain:**
```sql
ALTER TABLE payment_requests 
ADD COLUMN source_chain_id INTEGER,
ADD COLUMN bridge_tx_hash TEXT,
ADD COLUMN bridge_status TEXT;
```

### Token Management Best Practices

1. **Caching Strategy**
   - Cache token lists in Supabase
   - Refresh daily via scheduled function
   - Frontend caches in localStorage

2. **Custom Token Support**
   - Allow manual token address input
   - Validate contract is ERC20
   - Fetch metadata on-chain if needed

3. **Security Considerations**
   - Whitelist verified tokens by default
   - Warn users about unverified tokens
   - Check for token scam databases

## Payment Validation Rules (PoC)

### Amount Validation

**USD-Based Limits with Client-Side Price Fetching:**
```typescript
const VALIDATION_RULES = {
  MIN_AMOUNT_USD: 1,      // $1 minimum to avoid dust payments
  MAX_AMOUNT_USD: 10000,  // $10,000 maximum for safety
  
  // Price fetching config
  PRICE_CACHE_DURATION_MS: 300000, // Cache prices for 5 minutes
  PRICE_FETCH_TIMEOUT_MS: 5000,    // 5 second timeout for price API
}
```

**Price Service Implementation:**
```typescript
interface TokenPrice {
  usd: number
  lastUpdated: Date
}

class PriceService {
  private cache = new Map<string, TokenPrice>()
  
  async getTokenPriceUSD(tokenAddress: string, chainId: number): Promise<number | null> {
    const cacheKey = `${chainId}-${tokenAddress.toLowerCase()}`
    
    // Check cache first
    const cached = this.cache.get(cacheKey)
    if (cached && Date.now() - cached.lastUpdated.getTime() < VALIDATION_RULES.PRICE_CACHE_DURATION_MS) {
      return cached.usd
    }
    
    try {
      // Map token address to CoinGecko ID (maintained in our token list)
      const coingeckoId = await this.getCoinGeckoId(tokenAddress, chainId)
      if (!coingeckoId) return null
      
      // Fetch from CoinGecko free API
      const response = await fetch(
        `https://api.coingecko.com/api/v3/simple/price?ids=${coingeckoId}&vs_currencies=usd`,
        { signal: AbortSignal.timeout(VALIDATION_RULES.PRICE_FETCH_TIMEOUT_MS) }
      )
      
      const data = await response.json()
      const price = data[coingeckoId]?.usd
      
      if (price) {
        this.cache.set(cacheKey, { usd: price, lastUpdated: new Date() })
        return price
      }
      
      return null
    } catch (error) {
      console.warn('Failed to fetch token price:', error)
      return null
    }
  }
}
```

**Validation with Graceful Fallback:**
```typescript
async function validatePaymentAmount(
  tokenAddress: string,
  tokenSymbol: string,
  amount: bigint,
  decimals: number,
  chainId: number
): Promise<ValidationResult> {
  const normalizedAmount = Number(amount) / (10 ** decimals)
  
  // Try to get USD price
  const priceUSD = await priceService.getTokenPriceUSD(tokenAddress, chainId)
  
  if (priceUSD) {
    // We have a price - validate USD amounts
    const amountUSD = normalizedAmount * priceUSD
    
    if (amountUSD < VALIDATION_RULES.MIN_AMOUNT_USD) {
      return { 
        valid: false, 
        error: `Amount too small. Minimum: $${VALIDATION_RULES.MIN_AMOUNT_USD} (${(VALIDATION_RULES.MIN_AMOUNT_USD / priceUSD).toFixed(4)} ${tokenSymbol})` 
      }
    }
    
    if (amountUSD > VALIDATION_RULES.MAX_AMOUNT_USD) {
      return { 
        valid: false, 
        error: `Amount too large. Maximum: $${VALIDATION_RULES.MAX_AMOUNT_USD} (${(VALIDATION_RULES.MAX_AMOUNT_USD / priceUSD).toFixed(4)} ${tokenSymbol})` 
      }
    }
    
    return { valid: true, amountUSD }
  } else {
    // No price available - allow but warn
    return { 
      valid: true, 
      warning: `Unable to verify USD value for ${tokenSymbol}. Please ensure the amount is reasonable.`,
      amountUSD: null
    }
  }
}
```

**UI Implementation:**
```svelte
<!-- In CreateRequestForm.svelte -->
<script>
  let validationResult = await validatePaymentAmount(...)
  
  if (!validationResult.valid) {
    // Show error - prevent form submission
    errorMessage = validationResult.error
  } else if (validationResult.warning) {
    // Show warning but allow submission
    warningMessage = validationResult.warning
  } else {
    // Show USD equivalent for user confirmation
    usdDisplay = `≈ $${validationResult.amountUSD.toFixed(2)} USD`
  }
</script>

{#if errorMessage}
  <div class="text-red-500">{errorMessage}</div>
{:else if warningMessage}
  <div class="text-yellow-500">⚠️ {warningMessage}</div>
{:else if usdDisplay}
  <div class="text-gray-500">{usdDisplay}</div>
{/if}
```

**Token List Enhancement:**
```typescript
// Extend supported_tokens table
ALTER TABLE supported_tokens 
ADD COLUMN coingecko_id TEXT,
ADD COLUMN price_usd DECIMAL(20,8),
ADD COLUMN price_updated_at TIMESTAMPTZ;

// Popular tokens with CoinGecko IDs
const TOKEN_METADATA = {
  '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48': { symbol: 'USDC', coingeckoId: 'usd-coin' },
  '0xdAC17F958D2ee523a2206206994597C13D831ec7': { symbol: 'USDT', coingeckoId: 'tether' },
  '0x6B175474E89094C44Da98b954EedeAC495271d0F': { symbol: 'DAI', coingeckoId: 'dai' },
  '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': { symbol: 'WETH', coingeckoId: 'weth' },
  // ... more tokens
}
```

### Request Creation Validation

**Required Fields:**
```typescript
interface CreateRequestValidation {
  // Required fields
  recipientAddress: string    // Must be valid EVM address
  tokenAddress: string        // Must be in supported tokens list
  chainId: number            // Must be in supported chains
  
  // Optional but validated if provided
  amount?: string            // If provided, must pass amount validation
  description?: string       // Max 500 characters
  expiresAt?: Date          // Must be future date, max 90 days
}
```

**Validation Rules:**
1. **Address Validation**
   - Must be valid EVM address (0x + 40 hex chars)
   - Must pass checksum validation
   - Cannot be zero address

2. **Token Validation**
   - Must exist in supported_tokens table for the chain
   - Must be marked as is_active = true

3. **Expiry Validation**
   - Default: 180 days if not provided
   - Minimum: 1 hour from creation
   - Maximum: 365 days from creation (1 year)
   - UI provides preset options: 1 day, 7 days, 30 days, 180 days, 365 days, or custom

4. **Description Validation**
   - Optional field
   - Max 500 characters
   - Basic HTML/script sanitization

### Payment Fulfillment Validation

**Pre-Payment Checks:**
```typescript
interface PaymentValidation {
  // Request state
  requestStatus: 'pending'      // Must be pending
  requestNotExpired: boolean    // Current time < expiresAt
  
  // Payer validation
  sufficientBalance: boolean    // Payer balance >= amount
  correctNetwork: boolean       // Payer on same chain as request
  
  // Amount validation (for flexible amounts)
  amountValid: boolean         // Passes USD min/max if price available
  amountWarning?: string       // Warning if no price data
}
```

### Error Messages

**User-Friendly Messages:**
```typescript
const ERROR_MESSAGES = {
  AMOUNT_TOO_SMALL: "Minimum amount: ${min} USD",
  AMOUNT_TOO_LARGE: "Maximum amount: ${max} USD", 
  INSUFFICIENT_BALANCE: "Insufficient {token} balance",
  WRONG_NETWORK: "Please switch to {chainName}",
  REQUEST_EXPIRED: "This payment request has expired",
  REQUEST_ALREADY_PAID: "Already paid",
  INVALID_ADDRESS: "Invalid wallet address",
  TOKEN_NOT_SUPPORTED: "{token} not supported on {chainName}",
}
```

**Expiry Date UI Implementation:**
```svelte
<!-- In CreateRequestForm.svelte -->
<script>
  const EXPIRY_PRESETS = [
    { label: '1 day', days: 1 },
    { label: '1 week', days: 7 },
    { label: '1 month', days: 30 },
    { label: '6 months', days: 180, default: true },
    { label: '1 year', days: 365 },
    { label: 'Custom', days: null }
  ]
  
  let selectedPreset = EXPIRY_PRESETS.find(p => p.default)
  let customDate = null
  let expiresAt = new Date(Date.now() + 180 * 24 * 60 * 60 * 1000) // Default 180 days
  
  function updateExpiry(preset) {
    if (preset.days) {
      expiresAt = new Date(Date.now() + preset.days * 24 * 60 * 60 * 1000)
    }
  }
</script>

<div class="expiry-selector">
  <label>Request expires in:</label>
  <div class="preset-buttons">
    {#each EXPIRY_PRESETS as preset}
      <button 
        class:selected={selectedPreset === preset}
        on:click={() => { selectedPreset = preset; updateExpiry(preset); }}
      >
        {preset.label}
      </button>
    {/each}
  </div>
  
  {#if selectedPreset.days === null}
    <input 
      type="datetime-local" 
      bind:value={customDate}
      min={new Date(Date.now() + 3600000).toISOString().slice(0, 16)} // Min: 1 hour
      max={new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString().slice(0, 16)} // Max: 1 year
    />
  {/if}
  
  <p class="text-sm text-gray-500">
    Expires on: {expiresAt.toLocaleDateString()} at {expiresAt.toLocaleTimeString()}
  </p>
</div>
```

### 🟡 Design Decisions Needed

5. **Additional Validation Considerations**
   - How to handle tokens without CoinGecko listings?
   - Should we allow custom tokens not in our list?
   - Rate limiting for API calls to avoid hitting CoinGecko limits?

6. **User Experience**
   - Mobile responsiveness requirements
   - Offline functionality needs
   - Error handling and user feedback

7. **Security Considerations**
   - Rate limiting for request creation
   - Link sharing security
   - Wallet address validation

### 🟢 Optional Enhancements

8. **Advanced Features**
   - Recurring payment requests
   - Partial payments
   - Request templates
   - Email/SMS notifications
   - QR code generation
   - Multi-recipient requests

### 🔵 Post-POC Security Enhancements

**Authenticated Payment Request Access**
- **Current POC**: Payment requests are publicly viewable via shareable links
- **Future Enhancement**: 
  - Require payers to authenticate with their wallet before viewing request details
  - Implement wallet-based authentication for both creators and payers
  - Store viewer permissions in database
  - Benefits:
    - Enhanced privacy - payment amounts/details not publicly visible
    - Audit trail of who viewed each request
    - Ability to revoke access to specific wallets
    - Protection against request enumeration attacks
  - Implementation:
    - Add `allowed_viewers` table with wallet addresses
    - Update RLS policies to check authenticated wallet
    - Add wallet connection requirement to payment page

9. **Analytics and Monitoring**
   - Usage analytics
   - Transaction success rates
   - Error tracking and logging

10. **Integration Possibilities**
    - Social media sharing
    - Messaging app integrations
    - Invoice export functionality

## Next Steps

1. **Immediate**: Decide on data storage solution and backend architecture
2. **Phase 1**: Implement basic request creation and dashboard flows
3. **Phase 2**: Add payment fulfillment with transaction monitoring
4. **Phase 3**: Enhance UX and add optional features

---

*This design document should be updated as decisions are made and implementation progresses.*