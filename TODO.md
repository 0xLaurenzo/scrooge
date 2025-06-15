# Scrooge Payment Request App - Development TODO

## 🔍 Items Requiring Clarification (MUST BE RESOLVED FIRST)

### High Priority Clarifications
- [x] **Supabase Setup**: Confirm Supabase project is set up with API keys and connection details
- [x] **Token Support**: Specify which ERC20 tokens to support initially (USDC, USDT, DAI only?)
- [x] **Payment Validation**: Define minimum/maximum payment amounts and validation rules

### Medium Priority Clarifications
- [x] **Request Expiry**: Confirm default request expiry period (e.g., 7 days, 30 days)

---

## Phase 1: Foundation Setup (Start Here After Clarifications)

### Monorepo Setup
- [ ] Set up monorepo structure with packages/
  - [ ] packages/contracts - Solidity smart contracts
  - [ ] packages/web - SvelteKit frontend
  - [ ] packages/types - Shared types and utilities
- [ ] Configure workspace with pnpm/yarn workspaces
- [ ] Set up shared TypeScript configuration
- [ ] Configure build scripts for all packages

### Database Schema Updates
- [ ] Write migration SQL script for new schema
- [ ] Drop existing payment_requests table
- [ ] Create new payment_requests_cache table:
  - id (from IPFS CID)
  - ipfs_cid (unique)
  - created_by, recipient_address, chain_id
  - cached_data (JSONB)
  - status, payment tracking fields
- [ ] Create blockchain_events table for event logs
- [ ] Add performance indexes:
  - idx_created_by
  - idx_chain_id
  - idx_ipfs_cid
  - idx_status
- [ ] Remove RLS policies (data is public on IPFS)
- [ ] Test migration locally before production

### Smart Contract & Infrastructure
- [ ] Write ScroogePayments.sol with fee mechanism
- [ ] Write deployment scripts for multiple chains
- [ ] Deploy ScroogePayments contract on test networks
- [ ] Verify contracts on Etherscan/etc
- [ ] Set up IPFS integration with Pinata/Infura
- [ ] Configure multi-chain contract addresses

### Core Services
- [ ] Create IPFSService for uploading/retrieving payment requests
- [ ] Create ContractService for smart contract interactions
- [ ] Create RequestService with IPFS + caching logic
- [ ] Create TokenService for fetching token lists and balance checking
- [ ] Create EventMonitorService for blockchain event monitoring

### Supabase Edge Functions
- [ ] Create Edge Function: cache-payment-request (no auth required)
- [ ] Create Edge Function: get-user-requests with pagination
- [ ] Create Edge Function: update-payment-status (called by event monitor)

---

## Phase 2: Core Features Implementation

### Request Creation Flow (No Wallet Required)
- [ ] Build /create route with CreateRequestForm component
- [ ] Implement IPFS upload on form submission
- [ ] Implement TokenSelector component with Uniswap token list integration
- [ ] Generate shareable links with IPFS CID (/pay/[cid])

### Payment Flow (Through Smart Contract)
- [ ] Build /pay/[cid] public payment page fetching from IPFS
- [ ] Implement PaymentForm with two-step process:
  - [ ] ERC20 approval to smart contract
  - [ ] Contract payRequest function call
- [ ] Add network validation and automatic chain switching prompts
- [ ] Implement event monitoring for PaymentCompleted events
- [ ] Show fee breakdown (0.5% protocol fee)

---

## Phase 3: User Experience

### Dashboard & Management
- [ ] Build /dashboard route querying cached requests by wallet
- [ ] Create RequestCard component showing IPFS-stored details
- [ ] Implement real-time updates from blockchain events
- [ ] Add IPFS retrieval with fallback gateways

### UI/UX Improvements
- [ ] Build /pay/[cid]/success confirmation page
- [ ] Update landing page (/) highlighting decentralized features
- [ ] Add "Stored on IPFS" badge to requests
- [ ] Add fee calculator showing protocol fees
- [ ] Add mobile responsive design to all components
- [ ] Add proper error handling and user feedback across all flows

---

## Phase 4: Production Readiness

### Security & Performance
- [ ] Implement IPFS upload size limits
- [ ] Add fallback IPFS gateways for reliability
- [ ] Test smart contract interactions across all chains
- [ ] Implement event monitoring reliability (missed events handling)

### Documentation
- [ ] Create deployment configuration and environment setup guide

---

## Development Order Recommendation

1. **Deploy contracts first** - Deploy ScroogePayments on testnets
2. **IPFS integration** - Set up Pinata/Infura and test uploads
3. **Core services** - Build IPFSService, ContractService, EventMonitor
4. **Update database** - Modify schema for caching layer only
5. **Request creation flow** - Test IPFS upload without wallet
6. **Payment flow** - Test smart contract payments with fees
7. **Event monitoring** - Ensure reliable status updates
8. **Polish last** - Add error handling, multiple gateways, etc.

## Post-POC Features (Do Not Implement Yet)

### Advanced Decentralization
- Deploy to more EVM chains
- Implement cross-chain payment support
- Add ENS/unstoppable domains support
- Create DAO governance for fee adjustments

### Enhanced Features
- Batch payment requests
- Recurring payment schedules
- Payment request templates
- QR code generation for requests
- Mobile app with WalletConnect integration