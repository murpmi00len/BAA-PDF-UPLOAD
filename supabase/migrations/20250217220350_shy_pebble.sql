/*
  # Create storage bucket for file uploads

  1. New Storage Bucket
    - Creates a new public storage bucket named 'filestorage'
    - Enables RLS policies for secure access
  
  2. Security
    - Adds policies for authenticated users to:
      - Read files from the bucket
      - Upload files to the bucket
      - Delete their own files
*/

-- Create the storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('filestorage', 'filestorage', true)
ON CONFLICT (id) DO NOTHING;

-- Policy to allow authenticated users to read files
CREATE POLICY "Authenticated users can read files"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'filestorage');

-- Policy to allow authenticated users to upload files
CREATE POLICY "Authenticated users can upload files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'filestorage' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy to allow users to delete their own files
CREATE POLICY "Users can delete own files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'filestorage'
  AND auth.uid()::text = (storage.foldername(name))[1]
);