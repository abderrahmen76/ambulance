// Debug function to log all incoming headers
// This helps diagnose 401 issues

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  console.log(`[DebugHeaders] 🚀 Request received`)
  console.log(`[DebugHeaders] 📋 Method: ${req.method}`)
  console.log(`[DebugHeaders] 📋 URL: ${req.url}`)

  // Log ALL headers
  const headersObj: Record<string, string> = {}
  for (const [key, value] of req.headers.entries()) {
    const safeValue = key.toLowerCase().includes('authorization')
      ? `${value.substring(0, 40)}...`
      : value
    headersObj[key] = safeValue
    console.log(`[DebugHeaders] 📌 ${key}: ${safeValue}`)
  }

  const response = {
    message: 'Headers logged',
    headers_received: headersObj,
    has_authorization: req.headers.has('Authorization'),
    authorization_value: req.headers.get('Authorization')
      ? `${req.headers.get('Authorization')!.substring(0, 50)}...`
      : null,
  }

  return new Response(JSON.stringify(response), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status: 200,
  })
})
