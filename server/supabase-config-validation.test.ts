import assert from 'node:assert/strict';
import {describe, it} from 'node:test';

import {
  SetupValidationError,
  validateSupabaseConfigInput,
} from './supabase-config-validation.js';

function legacyKey(ref: string, role: string): string {
  const encode = (value: object) =>
    Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({alg: 'HS256', typ: 'JWT'})}.${encode({ref, role})}.signature`;
}

function expectInvalid(url: string, key: string, message: RegExp): void {
  assert.throws(
    () => validateSupabaseConfigInput(url, key),
    (error: unknown) =>
      error instanceof SetupValidationError && message.test(error.message),
  );
}

describe('validateSupabaseConfigInput', () => {
  it('accepts and normalizes a hosted project with a publishable key', () => {
    const result = validateSupabaseConfigInput(
      'https://exampleproject.supabase.co/',
      `sb_publishable_${'a'.repeat(32)}`,
    );

    assert.deepEqual(result, {
      supabaseUrl: 'https://exampleproject.supabase.co',
      supabasePublishableKey: `sb_publishable_${'a'.repeat(32)}`,
    });
  });

  it('accepts a matching legacy anon key', () => {
    const key = legacyKey('exampleproject', 'anon');
    const result = validateSupabaseConfigInput(
      'https://exampleproject.supabase.co',
      key,
    );

    assert.equal(result.supabasePublishableKey, key);
  });

  it('rejects secret and service-role keys', () => {
    expectInvalid(
      'https://exampleproject.supabase.co',
      `sb_secret_${'a'.repeat(32)}`,
      /Never enter a Supabase secret key/,
    );
    expectInvalid(
      'https://exampleproject.supabase.co',
      legacyKey('exampleproject', 'service_role'),
      /publishable key or the legacy anon key/,
    );
  });

  it('rejects a legacy key belonging to a different project', () => {
    expectInvalid(
      'https://exampleproject.supabase.co',
      legacyKey('differentproject', 'anon'),
      /belong to different projects/,
    );
  });

  it('rejects unsafe or unexpected URLs', () => {
    const key = `sb_publishable_${'a'.repeat(32)}`;
    expectInvalid('http://exampleproject.supabase.co', key, /HTTPS/);
    expectInvalid('https://example.com', key, /hosted/);
    expectInvalid(
      'https://exampleproject.supabase.co/rest/v1',
      key,
      /without a path/,
    );
  });
});
