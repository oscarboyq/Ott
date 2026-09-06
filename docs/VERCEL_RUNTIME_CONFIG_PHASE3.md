# Phase 3: Complete and lock the installation

> Historical implementation notes. For the current complete workflow, use
> [Owner setup and deployment](OWNER_SETUP_AND_DEPLOYMENT.md).

Phase 3 connects the Setup Wizard to the create-only Vercel setup endpoint.
Completing setup once now becomes installation-wide instead of browser-local.

## Final wizard flow

```text
Connect Supabase
    -> Run database SQL
    -> Verify database
    -> Create first admin account
    -> Enter REELHOUSE_SETUP_TOKEN
    -> POST /api/setup
    -> Private Blob is created with setupLocked: true
    -> Login/Home on every browser
```

The installation password is sent only to the same-origin Vercel Function over
HTTPS. Flutter does not persist it in SharedPreferences, localStorage, cookies,
or application configuration, and the server never returns it.

## Email confirmation

If Supabase requires email confirmation, the admin account is created first and
the global installation is then locked. The confirmation link returns to Login
and carries only the pending administrator email needed by the existing
first-admin completion flow. Supabase credentials are no longer placed in the
confirmation URL.

## Retry and conflict behavior

- Incorrect installation password: setup stays on the lock step and can retry.
- Invalid Supabase configuration: the server validation message is shown.
- Missing Blob/environment configuration: setup explains that Vercel is not
  configured yet.
- Lost success response: a repeated request receives HTTP 409, then Flutter
  reads the global configuration. It accepts the result only when the locked URL
  and publishable key exactly match the current setup.
- Different existing configuration: setup remains blocked and never overwrites
  the installation.

Blob reads bypass cache during installation checks, and the create operation
explicitly sets `allowOverwrite: false`.

## Required Vercel configuration

Before deploying:

1. Create a private Vercel Blob store and connect it to Production.
2. Confirm `BLOB_READ_WRITE_TOKEN` is available to Production.
3. Add a Production environment variable named `REELHOUSE_SETUP_TOKEN` with at
   least 32 characters.
4. Keep both tokens private and redeploy after changing environment variables.

Generate an installation token with:

```bash
openssl rand -hex 32
```

The person performing initial setup pastes that generated value into the final
wizard step. It is not a Supabase key.

## Normal behavior after setup

Every application startup calls `GET /api/runtime-config`. Once the Blob exists,
all browsers receive `configured: true` and `setupLocked: true`; `/setup` then
redirects to Login/Home. Flutter rebuilds and GitHub/Vercel redeployments do not
remove the Blob, so setup remains complete.
