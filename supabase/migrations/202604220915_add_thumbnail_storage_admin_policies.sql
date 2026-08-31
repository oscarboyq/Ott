-- Ensure the thumbnails bucket exists and is publicly readable.
INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'thumbnails',
  'thumbnails',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Anyone can view thumbnails" ON storage.objects;
DROP POLICY IF EXISTS "Admins can upload thumbnails" ON storage.objects;
DROP POLICY IF EXISTS "Admins can update thumbnails" ON storage.objects;
DROP POLICY IF EXISTS "Admins can delete thumbnails" ON storage.objects;

CREATE POLICY "Anyone can view thumbnails"
ON storage.objects
FOR SELECT
USING (bucket_id = 'thumbnails');

CREATE POLICY "Admins can upload thumbnails"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'thumbnails'
  AND (storage.foldername(name))[1] = 'admin'
  AND EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE id = auth.uid()
      AND is_admin = true
  )
);

CREATE POLICY "Admins can update thumbnails"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'thumbnails'
  AND EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE id = auth.uid()
      AND is_admin = true
  )
)
WITH CHECK (
  bucket_id = 'thumbnails'
  AND (storage.foldername(name))[1] = 'admin'
  AND EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE id = auth.uid()
      AND is_admin = true
  )
);

CREATE POLICY "Admins can delete thumbnails"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'thumbnails'
  AND EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE id = auth.uid()
      AND is_admin = true
  )
);