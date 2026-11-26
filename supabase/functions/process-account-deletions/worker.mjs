// Array target UID hanya berasal dari RPC privat, tidak pernah dari request HTTP.
export async function processQueue(admin, { requestId = null, limit = 3, now = Date.now } = {}) {
  const summary = { claimed: 0, completed: 0, retrying: 0 };
  const deadline = now() + 50_000;
  const { data: claims, error } = await admin.rpc('claim_automatic_account_deletions', {
    p_limit: limit, p_request_id: requestId,
  });
  if (error || !Array.isArray(claims)) return { ...summary, unavailable: true };
  summary.claimed = claims.length;
  for (const claim of claims) {
    const args = { p_request_id: claim.request_id, p_lease_id: claim.lease_id };
    try {
      if (now() >= deadline) throw new Error('Retry');
      const prepared = await admin.rpc('prepare_automatic_account_deletion', args);
      if (prepared.error || !Array.isArray(prepared.data?.auth_user_ids)) throw new Error('Retry');
      for (const uid of prepared.data.auth_user_ids) {
        if (now() >= deadline) throw new Error('Retry');
        const deletion = await admin.auth.admin.deleteUser(uid, false);
        if (deletion.error) {
          // Hanya not-found yang diverifikasi boleh dianggap telah dihapus.
          const check = await admin.auth.admin.getUserById(uid);
          if (!check.error || ![404].includes(check.error.status) ||
              !['user_not_found', 'not_found'].includes(check.error.code)) throw new Error('Retry');
        }
      }
      // RPC ini sendiri menolak completion apabila satu akun Auth masih tersisa.
      const completed = await admin.rpc('complete_automatic_account_deletion', args);
      if (completed.error || completed.data?.status !== 'completed') throw new Error('Retry');
      summary.completed += 1;
    } catch {
      summary.retrying += 1;
      // Bila jaringan gagal saat melepas lease, cron mengambil ulang setelah lease kedaluwarsa.
      try { await admin.rpc('retry_automatic_account_deletion', args); } catch { /* lease tetap aman */ }
    }
  }
  return summary;
}
