import test from 'node:test';
import assert from 'node:assert/strict';
import {app, until} from './harness.mjs';

test('business signup labels the organization and preserves the student name field', async () => {
 const ui = await app({role:'guest', audience:''});
 try {
  ui.click('List my business');
  await until(() => ui.document.querySelector('[placeholder="Business Name"]'));
  assert.equal(ui.document.querySelector('[placeholder="Business Name"]').autocomplete, 'organization');
  const select = ui.document.querySelector('[aria-label="Account type"]');
  select.value = 'student';
  select.dispatchEvent(new ui.window.Event('change', {bubbles:true}));
  await until(() => ui.document.querySelector('[placeholder="Your name"]'));
 } finally {ui.close();}
});

test('icon-only theme control sits beside logout and stays synchronized on Account', async () => {
 const ui = await app({role:'merchant'});
 try {
  const logout = ui.document.querySelector('[aria-label="Log out"]');
  const toggle = logout.parentElement.querySelector('[data-testid="theme-toggle"]');
  assert.ok(toggle);
  assert.equal(toggle.textContent, '');
  assert.ok(toggle.querySelector('svg'));
  toggle.click();
  await until(() => ui.document.documentElement.dataset.theme === 'dark');
  assert.equal(ui.window.localStorage.getItem('mlocal_theme'), 'dark');
  ui.click('Account');
  await until(() => ui.document.querySelectorAll('[data-testid="theme-toggle"]').length === 2);
  ui.document.querySelectorAll('[data-testid="theme-toggle"]')[1].click();
  await until(() => ui.document.documentElement.dataset.theme === 'light');
  assert.equal(ui.document.querySelectorAll('[aria-label="Switch to dark mode"]').length, 2);
  assert.deepEqual(ui.errors, []);
 } finally {ui.close();}
});
