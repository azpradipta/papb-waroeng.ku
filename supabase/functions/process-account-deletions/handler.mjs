import { processQueue } from './worker.mjs';

const json = (status, body) => new Response(JSON.stringify(body), {
  status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
});
function sameSecret(given, expected) {
  if (!given || !expected || expected.length < 32 || given.length !== expected.length) return false;
  let difference = 0;
  for (let i = 0; i < given.length; i += 1) difference |= given.charCodeAt(i) ^ expected.charCodeAt(i);
  return difference === 0;
}

export function createWorkerHandler({ admin, workerSecret, process = processQueue }) {
  return async (request) => {
    if (!sameSecret(request.headers.get('X-Worker-Secret'), workerSecret)) {
      return json(401, { error: 'Akses ditolak.', code: 'unauthorized' });
    }
    if (request.method !== 'POST') return json(405, { error: 'Metode tidak didukung.', code: 'method_not_allowed' });
    try {
      const summary = await process(admin);
      return summary.unavailable
        ? json(503, { error: 'Pemrosesan belum tersedia.', code: 'worker_unavailable' })
        : json(200, summary);
    } catch {
      return json(503, { error: 'Pemrosesan akan dicoba kembali.', code: 'worker_unavailable' });
    }
  };
}
