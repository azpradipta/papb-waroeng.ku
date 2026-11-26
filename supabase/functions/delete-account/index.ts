import { createClient } from '@supabase/supabase-js';
import { createHandler } from './handler.mjs';

declare const EdgeRuntime: { waitUntil: (promise: Promise<unknown>) => void };
const url = Deno.env.get('SUPABASE_URL')!;
function runtimeKey(dictionary: string, legacy: string): string {
  const keys = JSON.parse(Deno.env.get(dictionary) ?? '{}');
  return keys.default ?? Deno.env.get(legacy) ?? '';
}
const publishable = runtimeKey('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY');
const secret = runtimeKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY');
const options = {
  auth: { persistSession: false, autoRefreshToken: false },
  global: { fetch: (input: RequestInfo | URL, init?: RequestInit) =>
    fetch(input, { ...init, signal: AbortSignal.timeout(10_000) }) },
};
Deno.serve(createHandler({
  userClient: (token: string) => createClient(url, publishable, {
    ...options, global: { ...options.global, headers: { Authorization: `Bearer ${token}` } },
  }),
  passwordClient: () => createClient(url, publishable, options),
  admin: createClient(url, secret, options),
  workerSecret: Deno.env.get('WK_ACCOUNT_DELETION_WORKER_SECRET') ?? '',
  schedule: (work: Promise<unknown>) => EdgeRuntime.waitUntil(work),
}));
