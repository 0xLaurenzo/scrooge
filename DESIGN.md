# Scrooge - Payment Request App Design Document

## Overview

Scrooge is a crypto payment request application built on EVM-compatible blockchains. The app enables users to create, manage, and fulfill payment requests using ERC20 tokens through a simple web interface.

## Architecture

### Technology Stack
- **Frontend**: SvelteKit 5 with TypeScript
- **Backend**: Supabase (PostgreSQL database + Edge Functions)
- **Web3 Integration**: AppKit (Reown/WalletConnect) with Wagmi/Viem
- **Styling**: Tailwind CSS
- **Supported Networks**: Multi-chain EVM support (Mainnet, Arbitrum, Optimism, Polygon, Base + testnets)

### Current Infrastructure
- AppKit configured for wallet connections and chain switching
- Multi-chain support with 15+ EVM networks
- Professional wallet UI with automatic reconnection

## User Flows

### 1. Payment Request Creation Flow

**User Story**: As a user, I want to create a payment request so that I can receive payments from others.

**Flow**:
1. User connects wallet via AppKit
2. User navigates to "Create Request" page
3. User fills out request form:
   - Recipient address (auto-filled from connected wallet)
   - Token selection (ERC20 token dropdown)
   - Amount (fixed amount or "allow payer to specify")
   - Description/memo (optional)
   - Expiry date (optional)
4. User submits form
5. System generates unique request ID and shareable link
6. User receives confirmation with link to share

**Technical Requirements**:
- Form validation for addresses, amounts, token contracts
- Request data storage in Supabase PostgreSQL
- Unique ID generation (UUID)
- Shareable link generation

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
- Supabase RLS (Row Level Security) policies for wallet-based access
- Real-time status updates via Supabase Realtime subscriptions
- Request status tracking with database triggers
- Filtering and pagination using Supabase queries

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
7. Payer confirms and signs ERC20 transfer transaction
8. System monitors transaction status
9. On confirmation, request marked as "paid"
10. Both parties receive confirmation

**Technical Requirements**:
- ERC20 balance checking via Wagmi hooks
- Transaction building and signing via Wagmi
- Transaction monitoring:
  - Frontend: Real-time monitoring using Wagmi's waitForTransactionReceipt
  - Backend: Webhook endpoint (Supabase Edge Function) for transaction confirmation
- Status updates to database via API calls
- Network validation and switching prompts via AppKit

## Data Models

### Payment Request
```typescript
interface PaymentRequest {
  id: string                    // Unique identifier
  createdBy: string            // Creator wallet address
  recipientAddress: string     // Payment recipient address
  tokenAddress: string         // ERC20 token contract address
  tokenSymbol: string          // Token symbol (ETH, USDC, etc.)
  tokenDecimals: number        // Token decimals
  amount?: string              // Fixed amount (in wei), null for flexible
  description?: string         // Optional memo/description
  createdAt: Date             // Creation timestamp
  expiresAt?: Date            // Optional expiry date
  status: 'pending' | 'paid' | 'expired' | 'cancelled'
  paidBy?: string             // Payer wallet address
  transactionHash?: string    // Payment transaction hash
  paidAt?: Date              // Payment timestamp
  chainId: number            // Network chain ID
}
```

## Technical Implementation Areas

### Pages/Routes Required
- `/` - Landing page with app overview
- `/create` - Payment request creation form
- `/dashboard` - User dashboard for managing requests
- `/request/[id]` - Public payment request page
- `/request/[id]/success` - Payment confirmation page

### Components Required
- `CreateRequestForm.svelte` - Request creation form
- `RequestCard.svelte` - Request display component
- `PaymentForm.svelte` - Payment execution form
- `TokenSelector.svelte` - ERC20 token selection
- `RequestStatus.svelte` - Status display component
- `TransactionMonitor.svelte` - Transaction status tracking

### Services Required
- `RequestService` - CRUD operations for payment requests
- `TokenService` - ERC20 token information and balance checking
- `TransactionService` - Transaction building and monitoring
- `ValidationService` - Address, amount, and request validation

## Backend Architecture

### Data Storage (Supabase)
- **Database**: PostgreSQL with Supabase
- **Authentication**: Wallet-based authentication (no traditional auth needed)
- **Row Level Security**: Policies based on wallet addresses
- **Real-time**: Supabase Realtime for live updates

### Supabase Schema
```sql
-- Payment requests table
CREATE TABLE payment_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_by TEXT NOT NULL, -- wallet address
  recipient_address TEXT NOT NULL,
  token_address TEXT NOT NULL,
  token_symbol TEXT NOT NULL,
  token_decimals INTEGER NOT NULL,
  amount TEXT, -- nullable for flexible amounts
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'expired', 'cancelled')),
  paid_by TEXT,
  transaction_hash TEXT,
  paid_at TIMESTAMPTZ,
  chain_id INTEGER NOT NULL
);

-- Indexes for performance
CREATE INDEX idx_created_by ON payment_requests(created_by);
CREATE INDEX idx_status ON payment_requests(status);
CREATE INDEX idx_chain_id ON payment_requests(chain_id);

-- RLS policies
ALTER TABLE payment_requests ENABLE ROW LEVEL SECURITY;

-- Anyone can view requests (for payment links)
CREATE POLICY "Requests are viewable by anyone" 
  ON payment_requests FOR SELECT 
  USING (true);

-- Only creator can update their own requests
CREATE POLICY "Users can update own requests" 
  ON payment_requests FOR UPDATE 
  USING (created_by = current_user_id());
```

### Supabase Edge Functions

1. **create-payment-request**
   - Validates request data
   - Creates payment request record
   - Returns request ID and shareable link

2. **update-payment-status**
   - Webhook endpoint for transaction confirmations
   - Verifies transaction on-chain
   - Updates request status to 'paid'
   - Triggers notifications (if implemented)

3. **get-user-requests**
   - Returns paginated requests for a wallet address
   - Supports filtering by status, date, token

### Transaction Monitoring Strategy

1. **Frontend Monitoring** (Primary)
   - Uses Wagmi's `waitForTransactionReceipt` hook
   - Provides immediate feedback to user
   - Updates UI optimistically
   - Handles network issues gracefully

2. **Webhook Confirmation** (Backup)
   - Supabase Edge Function endpoint
   - Called by frontend after transaction confirmed
   - Double-checks transaction on-chain
   - Ensures database consistency
   - Handles edge cases (frontend crashes, etc.)

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