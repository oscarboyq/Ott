# Phase 2: Flutter runtime configuration bootstrap

> Historical implementation notes. For the current complete workflow, use
> [Owner setup and deployment](OWNER_SETUP_AND_DEPLOYMENT.md).

Phase 2 makes Flutter read the installation-wide configuration endpoint before
initializing Supabase or selecting a route. Supabase values are not required at
Flutter build time.

## Startup states

```text
GET /api/runtime-config
    |
    +-- configured: true  -> initialize Supabase -> Login/Home
    |
    +-- configured: false -> permit Setup Wizard
    |
    +-- API unavailable   -> show retry page, never Setup Wizard
```

Treating infrastructure failure separately is important. If a Blob outage were
treated as a fresh installation, ordinary users could suddenly see installer
screens on a configured OTT platform.

## Configuration priority

On Vercel, global runtime configuration is authoritative and overrides browser
storage. Browser persistence is retained temporarily for an unfinished wizard
and for local/native development.

In a production release, an unavailable or malformed runtime endpoint fails
closed with a **Configuration unavailable** page. In a Flutter debug build,
failure falls back to local configuration because `flutter run` does not host
Vercel Functions.

## Routing behavior

The trusted `setupLocked` value is installation-wide:

- `true`: `/setup` redirects to Login/Home on every browser and device.
- `false`: only `/setup` is allowed until the wizard completes and locks setup.

Local `setupCompleted` flags are no longer consulted when Vercel has returned a
definitive global state.

## Phase 3

Phase 2 reads global configuration. Phase 3 now adds the installation-token
screen and calls `POST /api/setup` after the database and first administrator
account are ready. See `VERCEL_RUNTIME_CONFIG_PHASE3.md`.
