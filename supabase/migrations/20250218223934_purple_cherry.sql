/*
  # Fix storage configuration and permissions
  
  1. Changes
    - Add proper storage bucket configuration
    - Update storage permissions
    - Add helper functions
    
  2. Security
    - Ensure proper RLS policies
    - Add secure bucket access
*/

-- Create helper function for storage initialization
CREATE OR REPLACE FUNCTION public.initialize_storage()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Ensure bucket exists
  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  VALUES (
    'filestorage',
    'filestorage',
    true,
    5242880,
    ARRAY['application/pdf']::text[]
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['application/pdf']::text[],
    updated_at = now();

  -- Ensure RLS is enabled
  ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

  -- Update storage policies
  DROP POLICY IF EXISTS "Allow authenticated read access" ON storage.objects;
  DROP POLICY IF EXISTS "Allow authenticated insert access" ON storage.objects;
  DROP POLICY IF EXISTS "Allow authenticated delete access" ON storage.objects;

  CREATE POLICY "Allow authenticated read access"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'filestorage');

  CREATE POLICY "Allow authenticated insert access"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'filestorage');

  CREATE POLICY "Allow authenticated delete access"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'filestorage' AND owner = auth.uid());

  RETURN true;
END;
$$;

-- Execute initialization
SELECT public.initialize_storage();