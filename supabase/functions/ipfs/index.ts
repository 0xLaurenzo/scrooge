import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { PinataSDK } from "npm:pinata@1.1.0"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PaymentRequestData {
  recipient: string
  amount: string
  token: string
  chainId: number
  description?: string
  createdAt: number
}

interface IPFSUploadResult {
  cid: string
  url: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const pinataJwt = Deno.env.get('PINATA_JWT')
    const pinataGateway = Deno.env.get('PINATA_GATEWAY')

    if (!pinataJwt) {
      throw new Error('PINATA_JWT environment variable not set')
    }

    const pinata = new PinataSDK({
      pinataJwt,
      pinataGateway,
    })

    const url = new URL(req.url)
    const pathname = url.pathname.replace('/ipfs', '')

    // Route handling
    switch (pathname) {
      case '/upload': {
        if (req.method !== 'POST') {
          return new Response('Method not allowed', { status: 405, headers: corsHeaders })
        }

        const data: PaymentRequestData = await req.json()

        // Validate required fields
        if (!data.recipient || !data.amount || !data.token || !data.chainId) {
          return new Response('Missing required fields', { status: 400, headers: corsHeaders })
        }

        // Create the JSON data to upload
        const jsonData = {
          ...data,
          version: '1.0',
          timestamp: Date.now()
        }

        // Upload to Pinata
        const result = await pinata.upload.json(jsonData, {
          metadata: {
            name: `payment-request-${data.recipient}-${data.amount}`,
            keyvalues: {
              recipient: data.recipient,
              amount: data.amount,
              token: data.token,
              chainId: data.chainId.toString()
            }
          }
        })

        const response: IPFSUploadResult = {
          cid: result.IpfsHash,
          url: `${pinataGateway}/ipfs/${result.IpfsHash}`
        }

        return new Response(JSON.stringify(response), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        })
      }

      case '/get': {
        if (req.method !== 'GET') {
          return new Response('Method not allowed', { status: 405, headers: corsHeaders })
        }

        const cid = url.searchParams.get('cid')
        if (!cid) {
          return new Response('Missing cid parameter', { status: 400, headers: corsHeaders })
        }

        const response = await fetch(`${pinataGateway}/ipfs/${cid}`)
        
        if (!response.ok) {
          return new Response(`Failed to fetch from IPFS: ${response.statusText}`, { 
            status: response.status, 
            headers: corsHeaders 
          })
        }

        const data = await response.json()

        // Validate the data structure
        if (!data.recipient || !data.amount || !data.token || !data.chainId) {
          return new Response('Invalid payment request data', { status: 400, headers: corsHeaders })
        }

        return new Response(JSON.stringify(data), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        })
      }

      case '/pin': {
        if (req.method !== 'POST') {
          return new Response('Method not allowed', { status: 405, headers: corsHeaders })
        }

        const { cid, name } = await req.json()
        if (!cid) {
          return new Response('Missing cid', { status: 400, headers: corsHeaders })
        }

        await pinata.pin.cid(cid, {
          metadata: {
            name: name || `payment-request-${cid}`
          }
        })

        return new Response(JSON.stringify({ success: true }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        })
      }

      case '/delete': {
        if (req.method !== 'DELETE') {
          return new Response('Method not allowed', { status: 405, headers: corsHeaders })
        }

        const { cid } = await req.json()
        if (!cid) {
          return new Response('Missing cid', { status: 400, headers: corsHeaders })
        }

        await pinata.files.delete([cid])

        return new Response(JSON.stringify({ success: true }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        })
      }

      case '/list': {
        if (req.method !== 'GET') {
          return new Response('Method not allowed', { status: 405, headers: corsHeaders })
        }

        const recipient = url.searchParams.get('recipient')
        const token = url.searchParams.get('token')
        const chainId = url.searchParams.get('chainId')

        const keyvalues: Record<string, string> = {}
        
        if (recipient) keyvalues.recipient = recipient
        if (token) keyvalues.token = token
        if (chainId) keyvalues.chainId = chainId

        const query = pinata.files.list()
        
        if (Object.keys(keyvalues).length > 0) {
          query.keyvalues(keyvalues)
        }

        const result = await query
        
        const files = result.files.map((file: any) => ({
          cid: file.cid,
          metadata: file.metadata
        }))

        return new Response(JSON.stringify({ files }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        })
      }

      default:
        return new Response('Not found', { status: 404, headers: corsHeaders })
    }
  } catch (error) {
    console.error('IPFS function error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500
    })
  }
})