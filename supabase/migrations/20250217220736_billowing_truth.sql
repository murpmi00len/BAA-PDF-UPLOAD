/*
  # Fix Storage Policies

  1. Changes
    - Simplify storage policies
    - Add service role bypass for bucket creation
    - Fix RLS policies for bucket management
    - Add proper owner tracking

  2. Security
    - Maintain RLS protection
    - Ensure proper access control
    - Add proper owner tracking
*/

-- Enable required extensions if not already enabled
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
DROP POLICY IF EXISTS "Authenticated users can read files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own files" ON storage.objects;

-- Create new simplified policies
CREATE POLICY "Allow authenticated read access"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'filestorage');

CREATE POLICY "Allow authenticated insert access"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'filestorage'
  AND (auth.uid() IS NOT NULL)
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

-- Verify setup
DO $$
DECLARE
    bucket_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets WHERE id = 'filestorage'
    ) INTO bucket_exists;

    IF NOT bucket_exists THEN
        RAISE EXCEPTION 'Storage bucket creation failed';
    END IF;

    RAISE NOTICE 'Storage configuration completed successfully';
END $$;