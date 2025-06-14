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

### 🟡 Design Decisions Needed

5. **Request Validation**
   - Minimum/maximum amounts
   - Supported tokens per network
   - Request expiry defaults

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