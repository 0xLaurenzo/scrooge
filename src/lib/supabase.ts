import { createClient } from '@supabase/supabase-js'
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public'

export const supabase = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY)

export type PaymentRequest = {
  id: string
  created_by: string
  recipient_address: string
  token_address: string
  token_symbol: string
  token_decimals: number
  amount?: string
  description?: string
  created_at: string
  expires_at?: string
  status: 'pending' | 'paid' | 'expired' | 'cancelled'
  paid_by?: string
  transaction_hash?: string
  paid_at?: string
  chain_id: number
}

export type SupportedToken = {
  address: string
  chain_id: number
  symbol: string
  name: string
  decimals: number
  logo_uri?: string
  is_active: boolean
  updated_at: string
}