# Scrooge Payment Request App - Development TODO

## 🔍 Items Requiring Clarification (MUST BE RESOLVED FIRST)

### High Priority Clarifications
- [ ] **Supabase Setup**: Confirm Supabase project is set up with API keys and connection details
- [ ] **Token Support**: Specify which ERC20 tokens to support initially (USDC, USDT, DAI only?)
- [ ] **Payment Validation**: Define minimum/maximum payment amounts and validation rules

### Medium Priority Clarifications
- [ ] **Request Expiry**: Confirm default request expiry period (e.g., 7 days, 30 days)

---

## Phase 1: Foundation Setup (Start Here After Clarifications)

### Database & Infrastructure
- [ ] Set up Supabase database with payment_requests table and RLS policies
- [ ] Create supported_tokens table and populate with initial token list from Uniswap
- [ ] Implement Supabase client configuration in the SvelteKit app

### Core Services
- [ ] Create RequestService for CRUD operations on payment requests
- [ ] Create TokenService for fetching token lists and balance checking
- [ ] Create TransactionService for building and monitoring transactions

### Supabase Edge Functions
- [ ] Create Edge Function: create-payment-request
- [ ] Create Edge Function: update-payment-status webhook
- [ ] Create Edge Function: get-user-requests with pagination

---

## Phase 2: Core Features Implementation

### Request Creation Flow
- [ ] Build /create route with CreateRequestForm component
- [ ] Implement TokenSelector component with Uniswap token list integration
- [ ] Implement shareable link generation and URL routing

### Payment Flow
- [ ] Build /request/[id] public payment page with request details display
- [ ] Implement PaymentForm component with ERC20 approval and transfer logic
- [ ] Add network validation and automatic chain switching prompts
- [ ] Implement TransactionMonitor component with real-time status updates

---

## Phase 3: User Experience

### Dashboard & Management
- [ ] Build /dashboard route with request filtering and status display
- [ ] Create RequestCard component for displaying payment request details
- [ ] Implement request expiry checking and status updates

### UI/UX Improvements
- [ ] Build /request/[id]/success confirmation page
- [ ] Update landing page (/) with app overview and features
- [ ] Add mobile responsive design to all components
- [ ] Add proper error handling and user feedback across all flows

---

## Phase 4: Production Readiness

### Security & Performance
- [ ] Implement rate limiting for request creation in Edge Functions
- [ ] Add comprehensive testing for wallet interactions and transactions

### Documentation
- [ ] Create deployment configuration and environment setup guide

---

## Development Order Recommendation

1. **Start with clarifications** - Get all the necessary information before coding
2. **Database first** - Set up Supabase tables and test connections
3. **Services before UI** - Build the backend logic before frontend components
4. **Test each flow end-to-end** - Complete one user flow before moving to the next
5. **Polish last** - Add error handling, mobile design, and rate limiting after core features work

## Post-POC Features (Do Not Implement Yet)

### Enhanced Security - Authenticated Payment Requests
- Require wallet authentication for viewing payment requests
- Remove public access to payment request details
- Implement allowed_viewers table and permissions
- Add wallet-based RLS policies