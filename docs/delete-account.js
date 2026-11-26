"use strict";

(() => {
  const config = window.WAROENG_KU_CONFIG || {};
  const loginForm = document.getElementById("login-form");
  const requestForm = document.getElementById("request-form");
  const requestPanel = document.getElementById("request-panel");
  const email = document.getElementById("email");
  const password = document.getElementById("password");
  const confirmationPassword = document.getElementById("confirmation-password");
  const consent = document.getElementById("consent");
  const loginButton = document.getElementById("login-button");
  const requestButton = document.getElementById("request-button");
  const logoutButton = document.getElementById("logout-button");
  const errorBox = document.getElementById("form-error");
  const result = document.getElementById("result");
  const supportEmail = config.supportEmail || "11231013@student.itk.ac.id";
  const supportLink = document.getElementById("support-link");
  supportLink.textContent = supportEmail;
  supportLink.href = `mailto:${encodeURIComponent(supportEmail)}?subject=Permintaan%20hapus%20akun%20Waroeng.Ku`;

  // Token hanya hidup dalam memori halaman; tidak memakai penyimpanan browser.
  let accessToken = null;
  let busy = false;
  let existingRequest = null;
  let ready = false;
  try {
    const key = config.publishableKey;
    const legacyParts = typeof key === "string" ? key.split(".") : [];
    const publicKey = typeof key === "string" && (/^sb_publishable_[A-Za-z0-9_-]{12,}$/.test(key) ||
      (legacyParts.length === 3 && JSON.parse(atob(legacyParts[1].replace(/-/g, "+").replace(/_/g, "/"))).role === "anon"));
    ready = new URL(config.supabaseUrl).protocol === "https:" &&
      publicKey;
  } catch (_) {
    ready = false;
  }
  document.getElementById("config-notice").hidden = ready;
  loginButton.disabled = !ready;

  function updateButtons() {
    loginButton.disabled = busy || !ready;
    requestButton.disabled = busy || !consent.checked || !confirmationPassword.value ||
      !accessToken || (!!existingRequest && existingRequest.status !== "pending");
    logoutButton.disabled = busy;
    email.disabled = busy;
    password.disabled = busy;
    confirmationPassword.disabled = busy;
    consent.disabled = busy;
    loginButton.textContent = busy ? "Memeriksa..." : "Lanjutkan ke Permintaan";
    requestButton.textContent = busy ? "Mengirim..." : "Konfirmasi Hapus Akun";
  }

  function showError(message) {
    errorBox.textContent = message;
    errorBox.hidden = !message;
  }

  function describeError(error) {
    if (error.name === "AbortError") return "Koneksi terlalu lama. Coba lagi atau hubungi pengelola melalui email.";
    if (error.status === 429) return "Terlalu banyak percobaan. Tunggu beberapa saat, lalu coba lagi.";
    if (error.code === "invalid_credentials") return "Email atau password salah. Periksa kembali data akun Anda.";
    if (error.code === "invalid_password") return "Password salah. Masukkan kembali password akun Anda.";
    if (error.status === 401 || error.status === 403) return "Sesi tidak tersedia. Masuk kembali, atau hubungi pengelola melalui email.";
    if (error.code === "PGRST202" || error.code === "42P01") return "Formulir belum dapat menerima permintaan. Ajukan penghapusan melalui email pengelola di bawah.";
    if (error.status === 404 || error.status === 503) return "Penghapusan otomatis belum tersedia. Coba lagi nanti atau ajukan penghapusan melalui email pengelola di bawah.";
    return "Permintaan belum berhasil. Periksa koneksi, coba lagi, atau hubungi pengelola melalui email.";
  }

  async function api(path, body = {}, token = accessToken) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20000);
    try {
      const response = await fetch(`${config.supabaseUrl.replace(/\/$/, "")}${path}`, {
        method: "POST",
        headers: {
          "apikey": config.publishableKey,
          ...(token ? {"Authorization": `Bearer ${token}`} : {}),
          "Content-Type": "application/json"
        },
        credentials: "omit",
        referrerPolicy: "no-referrer",
        cache: "no-store",
        body: JSON.stringify(body),
        signal: controller.signal
      });
      const data = await response.json().catch(() => null);
      if (!response.ok) {
        const error = new Error("Permintaan tidak berhasil.");
        error.status = response.status;
        error.code = data && (data.error_code || data.code || data.error);
        throw error;
      }
      return data;
    } finally {
      clearTimeout(timeout);
    }
  }

  async function endSession() {
    const token = accessToken;
    accessToken = null;
    password.value = "";
    confirmationPassword.value = "";
    email.value = "";
    consent.checked = false;
    if (!token) return;
    try {
      await api("/auth/v1/logout?scope=local", {}, token);
    } catch (_) {
      // Tetap bersihkan sesi halaman jika jaringan terputus saat keluar.
    }
  }

  function showRequest(request) {
    existingRequest = request;
    const needsConfirmation = request.status === "pending" && !!accessToken;
    requestForm.hidden = !needsConfirmation;
    result.replaceChildren();
    const heading = document.createElement("h3");
    heading.textContent = request.status === "completed" ? "Permintaan telah selesai diproses" :
      request.status === "processing" ? "Penghapusan sedang diproses" :
        needsConfirmation ? "Permintaan sebelumnya menunggu konfirmasi" : "Permintaan diterima untuk diproses otomatis";
    const number = document.createElement("p");
    number.textContent = `Nomor permintaan: ${request.id}`;
    const detail = document.createElement("p");
    detail.textContent = needsConfirmation ?
      "Konfirmasikan kembali menggunakan password untuk menjalankan penghapusan otomatis. Tidak perlu membuat permintaan lain." :
      request.status === "completed" ? "Penghapusan telah selesai. Simpan nomor permintaan jika perlu menghubungi pengelola." :
        "Server akan melanjutkan penghapusan secara otomatis. Simpan nomor permintaan untuk menghubungi pengelola jika proses mengalami gangguan. Halaman ini belum menyatakan data selesai dihapus.";
    result.append(heading, number, detail);
    result.hidden = false;
    result.focus();
  }

  consent.addEventListener("change", updateButtons);
  confirmationPassword.addEventListener("input", updateButtons);

  loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (busy || !ready || !loginForm.reportValidity()) return;
    busy = true;
    showError("");
    result.hidden = true;
    updateButtons();
    try {
      const auth = await api("/auth/v1/token?grant_type=password", {
        email: email.value.trim(), password: password.value
      }, null);
      if (!auth || typeof auth.access_token !== "string") throw new Error("Sesi tidak tersedia.");
      accessToken = auth.access_token;
      password.value = "";
      let profile = null;
      try {
        profile = await api("/rest/v1/rpc/get_my_profile");
      } catch (_) {
        // Kasir nonaktif tetap berhak mengajukan penghapusan akunnya sendiri.
      }
      document.getElementById("account-label").textContent = profile && profile.full_name ?
        `${profile.full_name} — ${profile.role}` : email.value.trim();
      document.getElementById("role-impact").textContent = profile && profile.role === "Pemilik" ?
        "Sebagai Pemilik, Anda meminta penghapusan akun, seluruh data toko, dan semua akun Kasir yang terkait. Simpan dokumen dan beri tahu Kasir terlebih dahulu." :
        profile && profile.role === "Kasir" ?
          "Sebagai Kasir, Anda meminta penghapusan akun dan data pribadi sendiri. Catatan penjualan toko tetap disimpan dengan nama Kasir dihapus." :
          "Pastikan dampaknya sesuai peran Anda: permintaan Pemilik mencakup seluruh toko dan semua akun Kasir terkait; permintaan Kasir hanya mencakup akun dan data pribadinya sendiri.";
      const previous = await api("/rest/v1/rpc/get_my_account_deletion_request");
      loginForm.hidden = true;
      requestPanel.hidden = false;
      existingRequest = null;
      requestForm.hidden = false;
      logoutButton.hidden = false;
      if (previous) {
        showRequest(previous);
        if (previous.status !== "pending") {
          await endSession();
          logoutButton.hidden = true;
        }
      }
    } catch (error) {
      await endSession();
      showError(describeError(error));
    } finally {
      password.value = "";
      busy = false;
      updateButtons();
    }
  });

  requestForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (busy || !accessToken || (existingRequest && existingRequest.status !== "pending") ||
      !confirmationPassword.value || !consent.checked || !requestForm.reportValidity()) return;
    if (!window.confirm("Hapus akun dan data sesuai dampak yang dijelaskan? Setelah dikonfirmasi, penghapusan dijalankan otomatis dan tidak dapat dibatalkan.")) return;
    busy = true;
    showError("");
    updateButtons();
    try {
      const request = await api("/functions/v1/delete-account", {
        password: confirmationPassword.value, confirm: true
      });
      if (!request || typeof request.id !== "string" || !["pending", "processing", "completed"].includes(request.status)) {
        throw new Error("Permintaan belum dapat dikonfirmasi.");
      }
      await endSession();
      showRequest(request);
      logoutButton.hidden = true;
    } catch (error) {
      if (error.status === 401 || error.status === 403) {
        await endSession();
        requestPanel.hidden = true;
        loginForm.hidden = false;
      }
      showError(describeError(error));
    } finally {
      confirmationPassword.value = "";
      busy = false;
      updateButtons();
    }
  });

  logoutButton.addEventListener("click", async () => {
    if (busy) return;
    busy = true;
    updateButtons();
    await endSession();
    requestPanel.hidden = true;
    loginForm.hidden = false;
    logoutButton.hidden = false;
    existingRequest = null;
    showError("");
    busy = false;
    updateButtons();
    email.focus();
  });

  window.addEventListener("pagehide", () => {
    const token = accessToken;
    accessToken = null;
    password.value = "";
    confirmationPassword.value = "";
    if (!token) return;
    fetch(`${config.supabaseUrl.replace(/\/$/, "")}/auth/v1/logout?scope=local`, {
      method: "POST",
      headers: {"apikey": config.publishableKey, "Authorization": `Bearer ${token}`},
      credentials: "omit",
      referrerPolicy: "no-referrer",
      keepalive: true
    }).catch(() => {});
  });
})();
