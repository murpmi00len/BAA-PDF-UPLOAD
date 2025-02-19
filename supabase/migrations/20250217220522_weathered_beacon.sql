/*
  # Complete storage setup fix

  1. Storage Configuration
    - Enables required extensions
    - Creates storage schema if needed
    - Sets up bucket with complete configuration
  
  2. Security
    - Enables RLS
    - Sets up comprehensive policies
*/

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pg_net";
CREATE EXTENSION IF NOT EXISTS "http";

-- Create storage schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS storage;

-- Create buckets table if it doesn't exist
CREATE TABLE IF NOT EXISTS storage.buckets (
    id text PRIMARY KEY,
    name text NOT NULL,
    owner uuid REFERENCES auth.users,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    public boolean DEFAULT FALSE,
    avif_autodetection boolean DEFAULT FALSE,
    file_size_limit bigint,
    allowed_mime_types text[]
);

-- Create objects table if it doesn't exist
CREATE TABLE IF NOT EXISTS storage.objects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    bucket_id text REFERENCES storage.buckets,
    name text,
    owner uuid REFERENCES auth.users,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    last_accessed_at timestamptz DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/')) STORED
);

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

-- Create storage.foldername function if it doesn't exist
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
    objects_table_exists boolean;
    rls_enabled boolean;
BEGIN
    -- Check if bucket exists
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets WHERE id = 'filestorage'
    ) INTO bucket_exists;

    -- Check if objects table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'storage' AND table_name = 'objects'
    ) INTO objects_table_exists;

    -- Check if RLS is enabled
    SELECT rls_enabled FROM pg_tables 
    WHERE schemaname = 'storage' AND tablename = 'objects'
    INTO rls_enabled;

    IF NOT bucket_exists THEN
        RAISE EXCEPTION 'Storage bucket creation failed';
    END IF;

    IF NOT objects_table_exists THEN
        RAISE EXCEPTION 'Storage objects table creation failed';
    END IF;

    IF NOT rls_enabled THEN
        RAISE EXCEPTION 'RLS not enabled on storage.objects';
    END IF;
END $$;