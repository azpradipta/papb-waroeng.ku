const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (status, data) => new Response(JSON.stringify(data), {
  status, headers: { ...cors, 'Content-Type': 'application/json' },
});
const validPassword = (value) => typeof value === 'string' && value.length >= 8 && value.length <= 128;

// Dependensi disuntikkan agar alur izin dan Auth Admin dapat diuji tanpa server.
export function createHandler({ userClient, admin }) {
  return async (request) => {
    if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
    if (request.method !== 'POST') return json(405, { error: 'Metode tidak didukung.' });
    const token = request.headers.get('Authorization')?.match(/^Bearer\s+(\S+)$/i)?.[1];
    if (!token) return json(401, { error: 'Silakan masuk terlebih dahulu.' });
    try {
      const client = userClient(token);
      const { data: auth, error: authError } = await client.auth.getUser(token);
      if (authError || !auth?.user) return json(401, { error: 'Sesi berakhir. Silakan masuk kembali.' });
      const { data: profile, error: profileError } = await client.rpc('get_my_profile');
      if (profileError || !profile || profile.id !== auth.user.id ||
          profile.role !== 'Pemilik' || !profile.is_active || !profile.store_id) {
        return json(403, { error: 'Hanya Pemilik aktif yang dapat mengelola akun Kasir.' });
      }
      const text = await request.text();
      if (text.length > 4096) return json(400, { error: 'Data akun terlalu panjang.' });
      let body;
      try { body = JSON.parse(text); } catch { return json(400, { error: 'Data akun tidak valid.' }); }
      if (!body || typeof body !== 'object' || Array.isArray(body)) {
        return json(400, { error: 'Data akun tidak valid.' });
      }
      if (!validPassword(body.password)) {
        return json(400, { error: 'Password harus terdiri dari 8 sampai 128 karakter.' });
      }
      if (body.action === 'create') {
        const name = typeof body.name === 'string' ? body.name.trim() : '';
        const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
        if (!name || name.length > 100 || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
          return json(400, { error: 'Nama atau email Kasir tidak valid.' });
        }
        const { data, error } = await admin.auth.admin.createUser({
          email, password: body.password, email_confirm: true,
          user_metadata: { full_name: name },
          app_metadata: { wk_cashier_store_id: profile.store_id },
        });
        if (error) {
          const duplicate = ['email_exists', 'user_already_exists', 'email_address_conflict'].includes(error.code);
          return json(duplicate ? 409 : 400, { error: duplicate
            ? 'Email sudah digunakan. Gunakan email lain untuk akun Kasir.'
            : 'Akun Kasir gagal dibuat. Periksa data akun atau hubungi pengelola aplikasi.' });
        }
        if (!data?.user) return json(500, { error: 'Akun Kasir belum berhasil dibuat.' });
        return json(201, { id: data.user.id, full_name: name, email, is_active: true });
      }
      if (body.action === 'reset_password') {
        if (typeof body.id !== 'string' || !/^[0-9a-f-]{36}$/i.test(body.id)) {
          return json(400, { error: 'ID Kasir tidak valid.' });
        }
        // RPC hanya mengembalikan Kasir milik toko Pemilik yang sedang masuk.
        const { data: cashier, error: cashierError } = await client.rpc('get_cashier', { p_id: body.id });
        if (cashierError || !cashier || cashier.role !== 'Kasir' || cashier.store_id !== profile.store_id) {
          return json(404, { error: 'Akun Kasir tidak ditemukan di toko ini.' });
        }
        const { error } = await admin.auth.admin.updateUserById(body.id, { password: body.password });
        return error ? json(400, { error: 'Password Kasir gagal diubah.' }) : json(200, { ok: true });
      }
      return json(400, { error: 'Aksi tidak dikenal.' });
    } catch {
      return json(500, { error: 'Pengelolaan akun gagal. Coba lagi.' });
    }
  };
}
