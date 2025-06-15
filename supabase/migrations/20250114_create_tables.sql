-- Create payment requests table
CREATE TABLE IF NOT EXISTS payment_requests (
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

-- Create indexes for performance
CREATE INDEX idx_created_by ON payment_requests(created_by);
CREATE INDEX idx_status ON payment_requests(status);
CREATE INDEX idx_chain_id ON payment_requests(chain_id);
CREATE INDEX idx_created_at ON payment_requests(created_at DESC);

-- Enable Row Level Security
ALTER TABLE payment_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Anyone can view requests (for payment links)
CREATE POLICY "Requests are viewable by anyone" 
  ON payment_requests FOR SELECT 
  USING (true);

-- Anyone can insert (create) requests
CREATE POLICY "Anyone can create requests" 
  ON payment_requests FOR INSERT 
  WITH CHECK (true);

-- Only creator can update their own requests
CREATE POLICY "Users can update own requests" 
  ON payment_requests FOR UPDATE 
  USING (created_by = auth.jwt() ->> 'sub' OR auth.jwt() IS NULL);

-- Create supported tokens table
CREATE TABLE IF NOT EXISTS supported_tokens (
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

-- Create index for token lookups
CREATE INDEX idx_token_chain ON supported_tokens(chain_id, is_active);
CREATE INDEX idx_token_symbol ON supported_tokens(symbol);

-- Enable RLS for supported tokens
ALTER TABLE supported_tokens ENABLE ROW LEVEL SECURITY;

-- Anyone can read supported tokens
CREATE POLICY "Tokens are viewable by anyone" 
  ON supported_tokens FOR SELECT 
  USING (true);

-- Only admin can modify tokens (you'll need to set up admin roles)
CREATE POLICY "Only admin can modify tokens" 
  ON supported_tokens FOR ALL 
  USING (false);

-- Function to automatically update expires_at if status changes to expired
CREATE OR REPLACE FUNCTION update_expired_requests()
RETURNS void AS $$
BEGIN
  UPDATE payment_requests
  SET status = 'expired'
  WHERE status = 'pending' 
    AND expires_at IS NOT NULL 
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Create a scheduled job to run the expiry check (requires pg_cron extension)
-- Note: You'll need to enable pg_cron in Supabase dashboard and create this job
-- SELECT cron.schedule('expire-payment-requests', '*/5 * * * *', 'SELECT update_expired_requests();');