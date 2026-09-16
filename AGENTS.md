# Project Agent Policy

## 1. Local Files & Internal Tools (Fully Autonomous)
- **Local Reading & Editing**: Freely read files, search the codebase, edit existing files, and create new files without asking for confirmation.
- **Local Development Tools**: Proactively run local checks, compilers, linters, tests, and build tools (`flutter test`, `dart analyze`, `dart fix`, etc.) automatically.

## 2. External, Remote, Database, & Git Operations (Ask User & Show Command)
- **NEVER automatically execute**:
  - **Git State Changes**: `git push`, `git commit`, `git merge`, `git rebase`, `git reset`, `git checkout`.
  - **Database Migrations & Remote Changes**: `supabase db push`, remote SQL schema migrations, altering production tables or records.
  - **Cloud Deployments**: Deploying functions or cloud services (`supabase functions deploy`, etc.).
- **Required Protocol for External/Database/Git Actions**:
  - Stop before running the command.
  - Ask the user for confirmation.
  - Present the exact command in a clear code block so the user can inspect and execute it themselves.
