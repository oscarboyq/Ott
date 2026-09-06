# Current installation and deployment guide

This supersedes the Vercel runtime-config Phase 1–3 guides. ReelHouse now uses
Flutter + Supabase directly. No Blob store, setup token, or Vercel API function
is needed for configuration. Never enter service-role/secret keys into Flutter.

## 1. Prepare the database

For a new empty Supabase project, run `assets/complete_database_setup.sql` in
SQL Editor. It includes the security and owner-only installation definitions.
`setup/complete_database_setup.sql` is an identical copy.

For an existing project initialized with the previous schema, apply these in
order through SQL Editor (do not rerun the entire fresh-install schema):

1. `supabase/migrations/202609010900_security_hardening.sql`
2. `supabase/migrations/202609060900_owner_only_installation.sql`

These preserve existing accounts and the `setup_completed` value. No owner is
chosen automatically. If an old installation was only marked complete in Blob
or browser storage, finish the new owner setup to set the database record.

## 2. Designate the owner

In Supabase Authentication > Users, create your owner account (or use your
existing account). Ensure its email is confirmed. Copy that account's user UUID.
Open `setup/designate_owner.sql`, replace `REPLACE_WITH_YOUR_AUTH_USER_UUID`,
and run the script in SQL Editor. It gives that account admin access and creates
the private owner record. Rerunning with the same UUID is safe; a different UUID
is rejected. Neither visitors nor other admins can assign the owner via the API.

## 3. Supply public configuration and build

Locally, fill `config/supabase.json` as described in
`PUBLIC_SUPABASE_CONFIGURATION.md`. For GitHub-connected Vercel builds, set
Production variables `SUPABASE_URL` and `SUPABASE_ANON_KEY` (publishable or anon).
Keep the existing Flutter SDK installation commands and run these before the
Flutter build:

```sh
npm ci
npm run config:web
flutter pub get
flutter build web
```

Output directory: `build/web`. The local JSON is ignored by Git, so the build
helper is required on Vercel. No `--dart-define` is required. Old Blob credentials
are unused; the code changes do not delete or revoke your external resources.

## 4. Finish the platform setup

Until completion, visitors see “Platform being configured.” Choose “Owner sign
in” and sign in with the designated account. Only that confirmed account can
open `/setup`. Choose the platform name and select “Complete setup.”

The database function atomically saves the platform name and completion status.
It verifies the caller against the private owner record and checks their admin
profile. Retries are safe. Direct client updates, inserts and deletes of the
completion record are blocked, including for ordinary admins.

After completion all browsers see Login/Home. Direct visits to `/setup` redirect
away. Rebuilds and deployments keep setup as long as the same database record is
preserved. Missing/unreadable status shows an error page, never a fresh installer.

## Verification before sharing the portfolio

- Anonymous visitor before setup: pending page, no installer.
- Signed-in nonowner before setup: pending page, no installer.
- Confirmed owner: can finish setup.
- Other users cannot call `complete_installation` successfully.
- After completion, new/incognito browser and `/setup` go to Login/Home.
- A redeploy preserves completion; a connection failure shows retry.

Automated SQL checks live in `supabase/tests/owner_installation.sql`. They create
Supabase-like auth shims and must run only in an isolated empty PostgreSQL DB,
never against a real Supabase project. They verify owner authorization, client
write protection, retry behavior and migration preservation. Live checks still
need the actual project's migration, credentials and owner designation.
