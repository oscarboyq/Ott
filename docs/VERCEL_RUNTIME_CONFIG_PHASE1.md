# Phase 1: Vercel runtime configuration backend

> Historical implementation notes. For the current complete workflow, use
> [Owner setup and deployment](OWNER_SETUP_AND_DEPLOYMENT.md).

Phase 1 adds persistent, installation-wide configuration without changing the
Flutter startup flow yet. The Flutter integration is Phase 2.

## Architecture

```text
Any browser
    |
    | GET /api/runtime-config
    v
Vercel Function
    |
    v
Private Vercel Blob: reelhouse/runtime-config.json
```

The Blob contains the Supabase project URL and publishable/legacy anon key.
Those values are public client configuration. The private Blob write token and
the ReelHouse setup token are server secrets and are never returned.

## Vercel dashboard preparation

1. Open the ReelHouse Vercel project.
2. Open **Storage** and create a **Private Blob** store named
   `reelhouse-runtime-config`.
3. Connect it to **Production**. Vercel creates `BLOB_READ_WRITE_TOKEN`.
4. Open **Settings > Environment Variables**.
5. Add `REELHOUSE_SETUP_TOKEN` to Production. It must contain at least 32
   characters. Generate one with `openssl rand -hex 32` and keep it private.
6. Redeploy after the GitHub changes are pushed.

Do not connect Preview deployments to the production Blob while developing the
installer. A preview could otherwise write or read the production installation
configuration.

## Endpoints

### `GET /api/runtime-config`

Before setup:

```json
{"configured": false}
```

After setup:

```json
{
  "configured": true,
  "setupLocked": true,
  "supabaseUrl": "https://project.supabase.co",
  "supabasePublishableKey": "sb_publishable_..."
}
```

If Blob storage is missing or unavailable, the endpoint returns HTTP 503. It
does not pretend the installation is new, because that could incorrectly expose
the Setup Wizard during an infrastructure failure.

### `POST /api/setup`

Expected JSON:

```json
{
  "setupToken": "the-private-installation-token",
  "supabaseUrl": "https://project.supabase.co",
  "supabasePublishableKey": "sb_publishable_..."
}
```

The endpoint:

1. verifies the installation token using constant-time digest comparison;
2. rejects setup if configuration already exists;
3. accepts only hosted HTTPS `*.supabase.co` project URLs;
4. rejects Supabase secret and service-role keys;
5. checks that a legacy anon JWT belongs to the supplied project;
6. calls Supabase Auth settings to verify the URL/key pair;
7. creates the Blob without overwrite permission; and
8. permanently returns `setup_already_completed` after a successful write.

Do not manually call `POST /api/setup`. A successful request creates and locks
the global configuration. The Flutter Setup Wizard calls it from its final
installation-lock step.

## Local checks

```bash
npm install
npm run check:api
npm run test:api
```

The tests verify accepted publishable/anon keys and rejection of secret,
service-role, mismatched-project, and unsafe URL inputs.
