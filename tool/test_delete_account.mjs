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

function page({ role = 'Pemilik', existing = null, failedProfile = false, key = publicKey, confirm = true, failRequest = false, failLogin = false } = {}) {
  const elements = new Map();
  const calls = [];
  let requestFails = failRequest;
  const request = { id: 'request-1', status: 'pending', requested_at: '2026-11-20T00:00:00Z' };
  const element = (id) => {
    if (!elements.has(id)) elements.set(id, new Element());
    return elements.get(id);
  };
  const context = {
    window: {
      WAROENG_KU_CONFIG: { supabaseUrl: 'https://example.supabase.co', publishableKey: key, supportEmail: '11231013@student.itk.ac.id' },
      confirm: () => confirm,
      addEventListener() {},
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
      }
      else if (path.endsWith('/get_my_profile')) {
        data = failedProfile ? { code: '42501' } : { full_name: 'Akun Uji', role };
        if (failedProfile) status = 403;
      } else if (path.endsWith('/get_my_account_deletion_request')) data = existing;
      else if (path.endsWith('/request_account_deletion')) {
        if (requestFails) { status = 500; data = { message: 'internal details must not be displayed' }; }
        else data = request;
      } else if (!path.endsWith('/logout')) assert.fail(`Unexpected endpoint ${path}`);
      return { ok: status < 400, status, json: async () => data };
    },
  };
  vm.runInNewContext(script, context, { filename: 'delete-account.js' });
  return { calls, element, retry: () => { requestFails = false; } };
}

async function login(page) {
  page.element('email').value = 'user@example.com';
  page.element('password').value = 'test-password';
  await page.element('login-form').event('submit');
}

async function consentAndSubmit(page) {
  page.element('consent').checked = true;
  await page.element('consent').event('change');
  await page.element('request-form').event('submit');
}

test('public web request authenticates only own account, confirms, then clears session', async () => {
  const value = page();
  await login(value);
  assert.equal(value.element('password').value, '');
  assert.match(value.element('role-impact').textContent, /seluruh data toko/);
  assert.equal(value.element('request-button').disabled, true);
  await value.element('request-form').event('submit');
  assert.equal(value.calls.filter((call) => call.path.endsWith('/request_account_deletion')).length, 0);
  await consentAndSubmit(value);
  const submission = value.calls.find((call) => call.path.endsWith('/request_account_deletion'));
  assert.deepEqual(JSON.parse(submission.body), { p_confirm: true });
  assert.equal(submission.headers.Authorization, 'Bearer test-user-token');
  assert.equal(submission.headers.apikey, publicKey);
  const signIn = value.calls.find((call) => call.path.endsWith('/token'));
  assert.deepEqual(JSON.parse(signIn.body), { email: 'user@example.com', password: 'test-password' });
  assert.equal(signIn.headers.Authorization, undefined);
  assert.equal(submission.credentials, 'omit');
  assert.ok(value.calls.some((call) => call.url.endsWith('/logout?scope=local')));
  assert.equal(value.element('password').value, '');
  assert.equal(value.element('email').value, '');
  assert.equal(value.element('request-button').disabled, true);
  assert.match(value.element('result').children[0].textContent, /menunggu diproses/);
  await consentAndSubmit(value);
  assert.equal(value.calls.filter((call) => call.path.endsWith('/request_account_deletion')).length, 1);
});

test('canceling final confirmation sends no deletion request', async () => {
  const value = page({ role: 'Kasir', confirm: false });
  await login(value);
  assert.match(value.element('role-impact').textContent, /data pribadi sendiri/);
  await consentAndSubmit(value);
  assert.equal(value.calls.filter((call) => call.path.endsWith('/request_account_deletion')).length, 0);
  await value.element('logout-button').event('click');
  assert.ok(value.calls.some((call) => call.url.endsWith('/logout?scope=local')));
  assert.equal(value.element('email').value, '');
});

test('disabled cashier can request deletion even when normal profile access is denied', async () => {
  const value = page({ failedProfile: true });
  await login(value);
  assert.match(value.element('role-impact').textContent, /sesuai peran/);
  await consentAndSubmit(value);
  assert.equal(value.element('result').hidden, false);
});

test('existing request is displayed without adding another and ends web session', async () => {
  const value = page({ existing: { id: 'saved', status: 'processing' } });
  await login(value);
  assert.match(value.element('result').children[0].textContent, /sedang diproses/);
  assert.equal(value.element('request-form').hidden, true);
  assert.equal(value.calls.filter((call) => call.path.endsWith('/request_account_deletion')).length, 0);
  assert.ok(value.calls.some((call) => call.url.endsWith('/logout?scope=local')));
});

test('network failure can be retried and does not expose internal response details', async () => {
  const value = page({ failRequest: true });
  await login(value);
  await consentAndSubmit(value);
  assert.match(value.element('form-error').textContent, /belum berhasil/);
  assert.doesNotMatch(value.element('form-error').textContent, /internal details/);
  value.retry();
  await consentAndSubmit(value);
  assert.equal(value.calls.filter((call) => call.path.endsWith('/request_account_deletion')).length, 2);
  assert.equal(value.element('result').hidden, false);
});

test('privileged configuration never enables the public login form', () => {
  for (const key of ['sb_secret_not_public_12345', `header.${Buffer.from(JSON.stringify({ role: 'service_role' })).toString('base64url')}.signature`]) {
    const value = page({ key });
    assert.equal(value.element('login-button').disabled, true);
    assert.equal(value.element('config-notice').hidden, false);
    assert.equal(value.calls.length, 0);
  }
});

test('incorrect credentials display a clear error and clear the password', async () => {
  const value = page({ failLogin: true });
  await login(value);
  assert.match(value.element('form-error').textContent, /Email atau password salah/);
  assert.equal(value.element('password').value, '');
  assert.equal(value.calls.length, 1);
});
