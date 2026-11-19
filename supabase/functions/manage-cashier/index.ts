import { createClient } from '@supabase/supabase-js';
import { createHandler } from './handler.mjs';

const url = Deno.env.get('SUPABASE_URL')!;
function runtimeKey(dictionary: string, legacy: string): string {
  const keys = JSON.parse(Deno.env.get(dictionary) ?? '{}');
  return keys.default ?? Deno.env.get(legacy) ?? '';
}
const publishable = runtimeKey('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY');
const secret = runtimeKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY');
const options = { auth: { persistSession: false, autoRefreshToken: false } };

Deno.serve(createHandler({
  userClient: (token: string) => createClient(url, publishable, {
    ...options,
    global: { headers: { Authorization: `Bearer ${token}` } },
  }),
  admin: createClient(url, secret, options),
}));
