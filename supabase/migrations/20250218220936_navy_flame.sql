/*
  # Fix storage bucket initialization and permissions

  1. Changes
    - Drop and recreate storage bucket with proper permissions
    - Add necessary policies for bucket access
    - Add function to ensure bucket exists on startup
  
  2. Security
    - Enable proper RLS policies for bucket access
    - Ensure authenticated users can access their storage
*/

-- First ensure storage extensions are enabled
CREATE EXTENSION IF NOT EXISTS "pg_net";
CREATE EXTENSION IF NOT EXISTS "http";

-- Ensure storage schema exists
CREATE SCHEMA IF NOT EXISTS storage;

-- Function to ensure bucket exists with proper permissions
CREATE OR REPLACE FUNCTION storage.ensure_bucket()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Create bucket if it doesn't exist
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
END;
$$;

-- Execute the function to ensure bucket exists
SELECT storage.ensure_bucket();

-- Ensure proper RLS policies exist
ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

-- Allow public access to bucket metadata
CREATE POLICY "Public bucket access"
ON storage.buckets FOR SELECT
TO public
USING (true);

-- Allow authenticated users to access the bucket
CREATE POLICY "Allow authenticated bucket access"
ON storage.buckets FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Notify of completion
DO $$
BEGIN
  RAISE NOTICE 'Storage bucket configuration completed successfully';
END $$;