import { createClient } from '@supabase/supabase-js';
import { createWorkerHandler } from './handler.mjs';

const url = Deno.env.get('SUPABASE_URL')!;
function runtimeKey(dictionary: string, legacy: string): string {
  const keys = JSON.parse(Deno.env.get(dictionary) ?? '{}');
  return keys.default ?? Deno.env.get(legacy) ?? '';
}
const secret = runtimeKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY');
const admin = createClient(url, secret, {
  auth: { persistSession: false, autoRefreshToken: false },
  global: { fetch: (input: RequestInfo | URL, init?: RequestInit) =>
    fetch(input, { ...init, signal: AbortSignal.timeout(10_000) }) },
});
Deno.serve(createWorkerHandler({ admin,
  workerSecret: Deno.env.get('WK_ACCOUNT_DELETION_WORKER_SECRET') ?? '',
}));
