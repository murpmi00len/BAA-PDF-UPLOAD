/*
  # Storage System Initialization

  1. Setup
    - Ensures storage extensions are enabled
    - Creates necessary schemas and tables
    - Configures storage bucket with proper settings

  2. Security
    - Enables RLS
    - Sets up access policies
    - Configures proper permissions
*/

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pg_net";
CREATE EXTENSION IF NOT EXISTS "http";

-- Create storage schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS storage;

-- Ensure buckets table exists with proper structure
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

-- Ensure objects table exists with proper structure
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

-- Create or update the filestorage bucket
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

-- Enable RLS on objects table
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Create or replace the foldername function
CREATE OR REPLACE FUNCTION storage.foldername(name text)
RETURNS text[]
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN string_to_array(name, '/');
END
$$;

-- Update policies
DO $$ 
BEGIN
    -- Drop existing policies
    DROP POLICY IF EXISTS "Authenticated users can read files" ON storage.objects;
    DROP POLICY IF EXISTS "Authenticated users can upload files" ON storage.objects;
    DROP POLICY IF EXISTS "Users can delete own files" ON storage.objects;

    -- Create new policies
    CREATE POLICY "Authenticated users can read files"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'filestorage'
        AND (
            auth.uid()::text = (storage.foldername(name))[1]
            OR (SELECT public FROM storage.buckets WHERE id = bucket_id)
        )
    );

    CREATE POLICY "Authenticated users can upload files"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'filestorage'
        AND auth.uid()::text = (storage.foldername(name))[1]
        AND (octet_length(COALESCE(name, '')) < 512)
    );

    CREATE POLICY "Users can delete own files"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'filestorage'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );
END $$;

-- Verify the setup
DO $$
DECLARE
    bucket_exists boolean;
    objects_table_exists boolean;
    rls_enabled boolean;
BEGIN
    -- Verify bucket exists
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets WHERE id = 'filestorage'
    ) INTO bucket_exists;

    -- Verify objects table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'storage' AND table_name = 'objects'
    ) INTO objects_table_exists;

    -- Verify RLS is enabled
    SELECT rls_enabled FROM pg_tables 
    WHERE schemaname = 'storage' AND tablename = 'objects'
    INTO rls_enabled;

    -- Raise exceptions if any verification fails
    IF NOT bucket_exists THEN
        RAISE EXCEPTION 'Storage bucket creation failed';
    END IF;

    IF NOT objects_table_exists THEN
        RAISE EXCEPTION 'Storage objects table creation failed';
    END IF;

    IF NOT rls_enabled THEN
        RAISE EXCEPTION 'RLS not enabled on storage.objects';
    END IF;

    RAISE NOTICE 'Storage system successfully initialized';
END $$;