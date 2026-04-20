declare module 'https://esm.sh/@supabase/supabase-js@2' {
  export function createClient(url: string, key: string): any;
}

declare namespace Deno {
  function serve(
    handler: (req: Request) => Response | Promise<Response>,
  ): void;

  namespace env {
    function get(key: string): string | undefined;
  }
}