/*
  # Fix storage bucket setup

  1. Storage Bucket Configuration
    - Ensures storage API is enabled
    - Creates bucket with proper configuration
    - Sets up all required policies
  
  2. Security
    - Enables RLS
    - Configures proper access policies
*/

-- Enable storage if not already enabled
CREATE EXTENSION IF NOT EXISTS "pg_net";
CREATE EXTENSION IF NOT EXISTS "http";

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
  allowed_mime_types = ARRAY['application/pdf']::text[];

-- Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Authenticated users can read files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own files" ON storage.objects;

-- Create comprehensive policies
CREATE POLICY "Authenticated users can read files"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'filestorage'
  AND (auth.uid()::text = (storage.foldername(name))[1])
);

CREATE POLICY "Authenticated users can upload files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'filestorage'
  AND (auth.uid()::text = (storage.foldername(name))[1])
  AND (octet_length(COALESCE(name, '')) < 512)
);

CREATE POLICY "Users can delete own files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'filestorage'
  AND (auth.uid()::text = (storage.foldername(name))[1])
);

-- Verify bucket exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'filestorage'
  ) THEN
    RAISE EXCEPTION 'Storage bucket creation failed';
  END IF;
END $$;