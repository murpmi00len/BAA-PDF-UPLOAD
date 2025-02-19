-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pg_net";
CREATE EXTENSION IF NOT EXISTS "http";

-- Ensure storage schema exists
CREATE SCHEMA IF NOT EXISTS storage;

-- Update buckets table
ALTER TABLE IF EXISTS storage.buckets
  ALTER COLUMN owner DROP NOT NULL,
  ALTER COLUMN public SET DEFAULT true;

-- Ensure the bucket exists with proper configuration
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'filestorage',
  'filestorage',
  true,
  5242880, -- 5MB limit
  ARRAY['application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE
SET 
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['application/pdf']::text[],
  updated_at = now();

-- Enable RLS on objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow authenticated read access" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated insert access" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated delete access" ON storage.objects;

-- Create new simplified policies with owner tracking
CREATE POLICY "Allow authenticated read access"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'filestorage'
  AND (owner = auth.uid() OR bucket_id IN (
    SELECT id FROM storage.buckets WHERE public = true
  ))
);

CREATE POLICY "Allow authenticated insert access"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'filestorage'
  AND owner = auth.uid()
);

CREATE POLICY "Allow authenticated delete access"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'filestorage'
  AND owner = auth.uid()
);

-- Create or replace helper functions
CREATE OR REPLACE FUNCTION storage.foldername(name text)
RETURNS text[]
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN string_to_array(name, '/');
END
$$;

-- Add trigger to set owner on insert
CREATE OR REPLACE FUNCTION storage.set_owner()
RETURNS TRIGGER AS $$
BEGIN
  NEW.owner = auth.uid();
  RETURN NEW;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER set_storage_owner
  BEFORE INSERT ON storage.objects
  FOR EACH ROW
  EXECUTE FUNCTION storage.set_owner();

-- Verify setup
DO $$
DECLARE
    bucket_exists boolean;
    policies_exist boolean;
BEGIN
    -- Check if bucket exists
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets WHERE id = 'filestorage'
    ) INTO bucket_exists;

    -- Check if policies exist
    SELECT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' 
        AND tablename = 'objects'
        AND policyname = 'Allow authenticated read access'
    ) INTO policies_exist;

    IF NOT bucket_exists THEN
        RAISE EXCEPTION 'Storage bucket creation failed';
    END IF;

    IF NOT policies_exist THEN
        RAISE EXCEPTION 'Storage policies creation failed';
    END IF;

    RAISE NOTICE 'Storage configuration completed successfully';
END $$;