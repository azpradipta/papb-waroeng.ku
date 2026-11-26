import { processQueue } from '../process-account-deletions/worker.mjs';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (status, body) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
});
const failure = (status, error, code) => json(status, { error, code });

export function createHandler({ userClient, passwordClient, admin, workerSecret, schedule, process = processQueue }) {
  return async (request) => {
    if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
    if (request.method !== 'POST') return failure(405, 'Metode tidak didukung.', 'method_not_allowed');
    const token = request.headers.get('Authorization')?.match(/^Bearer\s+(\S+)$/i)?.[1];
    if (!token) return failure(401, 'Silakan masuk terlebih dahulu.', 'invalid_session');
    let verifier;
    try {
      const auth = await userClient(token).auth.getUser(token);
      if (auth.error || !auth.data?.user?.id || !auth.data.user.email) {
        return failure(401, 'Sesi berakhir. Silakan masuk kembali.', 'invalid_session');
      }
      // Deploy parsial tidak boleh menerima permintaan otomatis tanpa konfigurasi worker.
      if (typeof workerSecret !== 'string' || workerSecret.length < 32) {
        return failure(503, 'Penghapusan otomatis belum tersedia. Hubungi pengelola.', 'configuration_error');
      }
      if (Number(request.headers.get('Content-Length') ?? 0) > 4096) {
        return failure(400, 'Data tidak valid.', 'invalid_request');
      }
      const text = await request.text();
      if (text.length > 4096) return failure(400, 'Data tidak valid.', 'invalid_request');
      let body;
      try { body = JSON.parse(text); } catch { return failure(400, 'Data tidak valid.', 'invalid_request'); }
      if (!body || typeof body !== 'object' || Array.isArray(body) ||
          Object.keys(body).some((key) => !['password', 'confirm'].includes(key)) ||
          body.confirm !== true || typeof body.password !== 'string' ||
          !body.password.length || body.password.length > 128) {
        return failure(400, 'Isi password dan konfirmasi penghapusan.', 'invalid_request');
      }
      // Client terpisah agar sesi reautentikasi tidak menimpa bearer JWT pemohon.
      verifier = passwordClient();
      const check = await verifier.auth.signInWithPassword({
        email: auth.data.user.email, password: body.password,
      });
      if (check.error || check.data?.user?.id !== auth.data.user.id) {
        return failure(400, 'Password tidak sesuai. Coba lagi.', 'invalid_password');
      }
      const queued = await admin.rpc('authorize_automatic_account_deletion', {
        p_user_id: auth.data.user.id, p_confirm: true,
      });
      if (queued.error || !queued.data?.id || !queued.data?.status) {
        return failure(503, 'Permintaan belum berhasil dikirim. Coba lagi.', 'queue_unavailable');
      }
      const processing = Promise.resolve().then(() => process(admin, {
        requestId: queued.data.id, limit: 1,
      })).catch(() => undefined);
      if (schedule) schedule(processing); else await processing;
      return json(202, { id: queued.data.id, status: queued.data.status,
        requested_at: queued.data.requested_at });
    } catch {
      return failure(503, 'Permintaan belum berhasil dikirim. Coba lagi.', 'temporarily_unavailable');
    } finally {
      if (verifier) {
        try { await verifier.auth.signOut({ scope: 'local' }); } catch { /* sesi verifikasi saja */ }
      }
    }
  };
}
