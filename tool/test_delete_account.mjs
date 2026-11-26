import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const script = readFileSync(new URL('../docs/delete-account.js', import.meta.url), 'utf8');
const publicKey = 'sb_publishable_public_test_only_12345';

class Element {
  constructor() {
    this.hidden = false;
    this.disabled = false;
    this.checked = false;
    this.value = '';
    this.textContent = '';
    this.events = new Map();
    this.children = [];
  }
  addEventListener(name, action) { this.events.set(name, action); }
  reportValidity() { return true; }
  replaceChildren() { this.children = []; }
  append(...children) { this.children.push(...children); }
  focus() {}
  async event(name) { return this.events.get(name)?.({ preventDefault() {} }); }
}

function page({ role = 'Pemilik', existing = null, failedProfile = false,
  key = publicKey, confirm = true, requestError = null, failLogin = false,
  responseStatus = 'pending', failLogout = false } = {}) {
  const elements = new Map();
  const calls = [];
  const windowEvents = new Map();
  let failure = requestError;
  const request = { id: existing?.id || 'request-1', status: responseStatus,
    requested_at: '2026-11-26T00:00:00Z' };
  const element = (id) => {
    if (!elements.has(id)) elements.set(id, new Element());
    return elements.get(id);
  };
  const context = {
    window: {
      WAROENG_KU_CONFIG: { supabaseUrl: 'https://example.supabase.co',
        publishableKey: key, supportEmail: '11231013@student.itk.ac.id' },
      confirm: () => confirm,
      addEventListener(name, action) { windowEvents.set(name, action); },
    },
    document: { getElementById: element, createElement: () => new Element() },
    URL, AbortController, setTimeout, clearTimeout,
    atob: (value) => Buffer.from(value, 'base64').toString('binary'),
    fetch: async (url, options) => {
      const path = new URL(url).pathname;
      calls.push({ url, path, ...options });
      let data = null;
      let status = 200;
      if (path.endsWith('/token')) {
        data = failLogin ? { code: 400, error_code: 'invalid_credentials' } :
          { access_token: 'test-user-token', refresh_token: 'unused-refresh-token' };
        if (failLogin) status = 400;
      } else if (path.endsWith('/get_my_profile')) {
        data = failedProfile ? { code: '42501' } : { full_name: 'Akun Uji', role };
        if (failedProfile) status = 403;
      } else if (path.endsWith('/get_my_account_deletion_request')) data = existing;
      else if (path === '/functions/v1/delete-account') {
        if (failure === 'network') throw new TypeError('network unavailable');
        if (failure) {
          status = failure.status;
          data = { code: failure.code, error: 'internal details must not be displayed' };
        } else { data = request; status = 202; }
      } else if (path.endsWith('/logout')) {
        if (failLogout) { status = 401; data = { code: 'session_not_found' }; }
      } else assert.fail(`Unexpected endpoint ${path}`);
      return { ok: status < 400, status, json: async () => data };
    },
  };
  vm.runInNewContext(script, context, { filename: 'delete-account.js' });
  return { calls, element, windowEvents, retry: () => { failure = null; } };
}

function submissions(value) {
  return value.calls.filter((call) => call.path === '/functions/v1/delete-account');
}

async function login(value) {
  value.element('email').value = 'user@example.com';
  value.element('password').value = 'initial-login-password';
  await value.element('login-form').event('submit');
}

async function consentAndSubmit(value, password = 'fresh-confirmation-password') {
  value.element('consent').checked = true;
  value.element('confirmation-password').value = password;
  await value.element('consent').event('change');
  await value.element('confirmation-password').event('input');
  await value.element('request-form').event('submit');
}

test('202 request uses fresh password, own bearer, no UID or direct RPC, then clears session', async () => {
  const value = page();
  await login(value);
  assert.equal(value.element('password').value, '');
  assert.match(value.element('role-impact').textContent, /seluruh data toko/);
  assert.equal(value.element('request-button').disabled, true);
  await value.element('request-form').event('submit');
  assert.equal(submissions(value).length, 0);
  await consentAndSubmit(value);
  const submission = submissions(value)[0];
  assert.deepEqual(JSON.parse(submission.body), {
    password: 'fresh-confirmation-password', confirm: true,
  });
  assert.equal(submission.headers.Authorization, 'Bearer test-user-token');
  assert.equal(submission.headers.apikey, publicKey);
  const signIn = value.calls.find((call) => call.path.endsWith('/token'));
  assert.deepEqual(JSON.parse(signIn.body), {
    email: 'user@example.com', password: 'initial-login-password',
  });
  assert.equal(signIn.headers.Authorization, undefined);
  assert.equal(submission.credentials, 'omit');
  assert.ok(value.calls.some((call) => call.url.endsWith('/logout?scope=local')));
  for (const id of ['password', 'confirmation-password', 'email']) {
    assert.equal(value.element(id).value, '');
  }
  assert.equal(value.element('request-button').disabled, true);
  assert.match(value.element('result').children[0].textContent, /diproses otomatis/);
  assert.match(value.element('result').children[2].textContent, /belum menyatakan data selesai/);
  await consentAndSubmit(value);
  assert.equal(submissions(value).length, 1);
  assert.ok(!value.calls.some((call) => call.path.endsWith('/request_account_deletion')));
});

test('canceling final confirmation sends no deletion request', async () => {
  const value = page({ role: 'Kasir', confirm: false });
  await login(value);
  assert.match(value.element('role-impact').textContent, /data pribadi sendiri/);
  await consentAndSubmit(value);
  assert.equal(submissions(value).length, 0);
  await value.element('logout-button').event('click');
  assert.equal(value.element('confirmation-password').value, '');
  assert.equal(value.element('email').value, '');
});

test('disabled cashier can confirm even when normal profile access is denied', async () => {
  const value = page({ failedProfile: true });
  await login(value);
  assert.match(value.element('role-impact').textContent, /seluruh toko dan semua akun Kasir/);
  await consentAndSubmit(value);
  assert.equal(value.element('result').hidden, false);
  assert.equal(submissions(value).length, 1);
});

test('legacy pending request remains confirmable and resumes same ID through automatic endpoint', async () => {
  const value = page({ existing: { id: 'old-request', status: 'pending' } });
  await login(value);
  assert.match(value.element('result').children[0].textContent, /menunggu konfirmasi/);
  assert.equal(value.element('request-form').hidden, false);
  assert.equal(value.calls.filter((call) => call.path.endsWith('/logout')).length, 0);
  await consentAndSubmit(value);
  assert.equal(submissions(value).length, 1);
  assert.match(value.element('result').children[1].textContent, /old-request/);
  assert.equal(JSON.parse(submissions(value)[0].body).request_id, undefined);
});

test('existing processing or completed request is displayed without submitting again', async () => {
  for (const status of ['processing', 'completed']) {
    const value = page({ existing: { id: 'saved', status } });
    await login(value);
    assert.match(value.element('result').children[0].textContent,
      status === 'processing' ? /sedang diproses/ : /telah selesai/);
    assert.equal(value.element('request-form').hidden, true);
    await consentAndSubmit(value);
    assert.equal(submissions(value).length, 0);
    assert.ok(value.calls.some((call) => call.url.endsWith('/logout?scope=local')));
  }
});

test('wrong confirmation password clears password and retains session for safe retry', async () => {
  const value = page({ requestError: { status: 400, code: 'invalid_password' } });
  await login(value);
  await consentAndSubmit(value, 'wrong-password');
  assert.match(value.element('form-error').textContent, /Password salah/);
  assert.equal(value.element('confirmation-password').value, '');
  assert.equal(value.element('request-button').disabled, true);
  assert.ok(!value.calls.some((call) => call.path.endsWith('/logout')));
  value.retry();
  await consentAndSubmit(value, 'corrected-password');
  assert.equal(submissions(value).length, 2);
  assert.equal(JSON.parse(submissions(value)[1].body).password, 'corrected-password');
});

test('network/server failure can be retried and never exposes internal response details', async () => {
  for (const requestError of ['network', { status: 500, code: 'internal' }]) {
    const value = page({ requestError });
    await login(value);
    await consentAndSubmit(value);
    assert.match(value.element('form-error').textContent, /belum berhasil/);
    assert.doesNotMatch(value.element('form-error').textContent, /internal details|network unavailable/);
    assert.equal(value.element('confirmation-password').value, '');
    value.retry();
    await consentAndSubmit(value);
    assert.equal(submissions(value).length, 2);
    assert.equal(value.element('result').hidden, false);
  }
});

test('unavailable automation offers email fallback without bypassing password via legacy RPC', async () => {
  for (const status of [404, 503]) {
    const value = page({ requestError: { status, code: 'unavailable' } });
    await login(value);
    await consentAndSubmit(value);
    assert.match(value.element('form-error').textContent, /otomatis belum tersedia/);
    assert.ok(!value.calls.some((call) => call.path.endsWith('/request_account_deletion')));
  }
});

test('duplicate submit while busy makes one automatic request', async () => {
  const value = page();
  await login(value);
  value.element('confirmation-password').value = 'fresh-confirmation-password';
  value.element('consent').checked = true;
  await Promise.all([value.element('request-form').event('submit'),
    value.element('request-form').event('submit')]);
  assert.equal(submissions(value).length, 1);
});

test('expired session clears credentials and returns to login', async () => {
  const value = page({ requestError: { status: 401, code: 'auth_required' } });
  await login(value);
  await consentAndSubmit(value);
  assert.equal(value.element('request-panel').hidden, true);
  assert.equal(value.element('login-form').hidden, false);
  assert.equal(value.element('confirmation-password').value, '');
  assert.equal(value.element('email').value, '');
});

test('logout failure after accepted deletion still clears browser session', async () => {
  const value = page({ failLogout: true });
  await login(value);
  await consentAndSubmit(value);
  assert.equal(value.element('result').hidden, false);
  assert.equal(value.element('confirmation-password').value, '');
  await consentAndSubmit(value);
  assert.equal(submissions(value).length, 1);
});

test('pagehide clears passwords and makes best-effort logout without browser storage', async () => {
  const value = page();
  await login(value);
  value.element('confirmation-password').value = 'not-submitted';
  value.windowEvents.get('pagehide')();
  assert.equal(value.element('password').value, '');
  assert.equal(value.element('confirmation-password').value, '');
  assert.equal(value.calls.at(-1).keepalive, true);
  await consentAndSubmit(value);
  assert.equal(submissions(value).length, 0);
  assert.doesNotMatch(script, /localStorage|sessionStorage|document\.cookie/);
});

test('privileged configuration never enables the public login form', () => {
  for (const key of ['sb_secret_not_public_12345',
    `header.${Buffer.from(JSON.stringify({ role: 'service_role' })).toString('base64url')}.signature`]) {
    const value = page({ key });
    assert.equal(value.element('login-button').disabled, true);
    assert.equal(value.element('config-notice').hidden, false);
    assert.equal(value.calls.length, 0);
  }
});

test('incorrect login credentials show a clear error and clear the password', async () => {
  const value = page({ failLogin: true });
  await login(value);
  assert.match(value.element('form-error').textContent, /Email atau password salah/);
  assert.equal(value.element('password').value, '');
  assert.equal(value.calls.length, 1);
});
