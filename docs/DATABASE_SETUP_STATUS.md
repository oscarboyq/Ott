# Step 2: Database-authoritative installation status

> Historical implementation notes. For the current complete workflow, use
> [Owner setup and deployment](OWNER_SETUP_AND_DEPLOYMENT.md).

The router reads `public.app_settings` where `key = 'setup_completed'` on
navigation and authentication changes, on web and native platforms alike.
Browser completion flags and legacy Vercel Blob state are not routing inputs.

- String `true`: installation is complete; `/setup` redirects to Login/Home.
- String `false`: installation is incomplete; setup and login are reachable.
  Login is needed for email confirmation and existing owner accounts.
- Missing/invalid row, permission error, timeout or network failure: show
  `/installation-unavailable` with retry. Never silently reopen the installer.

Completion updates must return an affected row and pass a read-back check.
A rejected or zero-row update cannot report successful completion.

## Deployment prerequisites

Apply the database schema before using the browser wizard. The existing setup
SQL seeds `setup_completed = 'false'` with `is_secret = false` and contains a
SELECT policy for non-secret settings. Both signed-out and signed-in clients
must have the necessary SELECT grants and RLS access to this row. A missing
table or inaccessible status now intentionally shows the error page rather
than the SQL wizard. Existing completed installations must retain their true
database value; a previous browser or Blob flag alone is no longer sufficient.

Database setup and owner provisioning instructions will be simplified further
in Step 3. The current first-admin bootstrap mechanism still needs replacement
with explicit owner designation; this step does not change authorization SQL.

## Verification

Service tests cover true/false, fresh reads, malformed or missing status,
permission/network errors, successful updates and denied updates. Live browser
verification requires the configured Supabase project: finish setup, open an
incognito window, visit `/setup` directly, rebuild/redeploy, and verify that
all still lead to Login/Home. Temporarily losing connectivity must show the
retry screen and must not change the stored status.
