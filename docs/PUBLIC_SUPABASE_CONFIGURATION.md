# Step 1: Public Supabase configuration file

> Historical implementation notes. For the current complete workflow, use
> [Owner setup and deployment](OWNER_SETUP_AND_DEPLOYMENT.md).

This replaces the earlier Vercel Blob configuration design for app startup.
The old Phase 1–3 documents describe the previous design, not this startup flow.

Edit `config/supabase.json` locally:

```json
{
  "supabaseUrl": "https://YOUR-PROJECT.supabase.co",
  "supabaseAnonKey": "YOUR-PUBLISHABLE-OR-LEGACY-ANON-KEY"
}
```

The file is ignored by Git. On a fresh clone, copy
`config/supabase.example.json` to `config/supabase.json` and fill both fields.
Only use the public client key. The app bundles this asset, so visitors can
download its contents. Gitignore keeps local values out of source control;
it does not make bundled values private. RLS and database grants protect data.

Run `flutter run -d chrome` or `flutter build web` normally. No dart-define is
required. Changes to the file require a restart/rebuild. Startup validates the
file and initializes Supabase directly, without consulting Blob, config.js,
URL parameters, or browser-stored connection values. Invalid configuration
shows an error page rather than asking visitors to enter credentials.

## GitHub-connected Vercel builds

The ignored local file will not arrive through GitHub. Set `SUPABASE_URL` and
`SUPABASE_ANON_KEY` in Vercel's Production environment variables, then run:

```sh
npm ci
npm run config:web
# Keep your existing Flutter SDK installation/preparation commands here.
flutter pub get
flutter build web
```

Add `npm run config:web` after npm dependency installation and before the
existing Flutter build command. It creates the same JSON asset using only the
two public values. This is build preparation, not a server endpoint. Keep the
project root at the repository root and the Flutter output at `build/web`.
The script does not print the values. A missing or privileged key fails before
writing the file. Alternatively, publishing an already-built `build/web`
includes the asset created on your own computer.

## Scope of this step

The wizard no longer collects connection values. The existing SQL/admin setup
and legacy completion logic remain temporarily. Database-authoritative setup
status and secure owner-only setup are the next steps, so this intermediate
change alone is not a verified final installer. Existing Blob resources are
not deleted; startup simply no longer reads them.

The supplied local JSON starts empty: fill it before testing a live connection.
