import { mkdir, writeFile } from 'node:fs/promises';
import { validateSupabaseConfigInput } from '../server/supabase-config-validation.js';

// Run before Flutter's build on GitHub/Vercel, where the ignored local file
// does not exist. Emit only the two public configuration fields.
async function main(): Promise<void> {
  const config = validateSupabaseConfigInput(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_ANON_KEY,
  );
  await mkdir('config', { recursive: true });
  await writeFile('config/supabase.json', JSON.stringify({
    supabaseUrl: config.supabaseUrl,
    supabaseAnonKey: config.supabasePublishableKey,
  }, null, 2) + '\n');
  console.log('Created public Supabase configuration for the Flutter build.');
}

main().catch(() => {
  console.error('Set SUPABASE_URL and SUPABASE_ANON_KEY to a hosted project URL and public client key.');
  process.exitCode = 1;
});
