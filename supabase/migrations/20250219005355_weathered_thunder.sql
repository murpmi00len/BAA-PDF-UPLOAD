-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.initialize_storage();

-- Create initialize_storage function with proper parameters and return type
CREATE OR REPLACE FUNCTION public.initialize_storage()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  bucket_id text := 'filestorage';
  result jsonb;
BEGIN
  -- Ensure bucket exists
  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  VALUES (
    bucket_id,
    bucket_id,
    true,
    5242880, -- 5MB limit
    ARRAY['application/pdf']::text[]
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['application/pdf']::text[],
    updated_at = now()
  RETURNING jsonb_build_object(
    'id', id,
    'name', name,
    'public', public,
    'created_at', created_at,
    'updated_at', updated_at
  ) INTO result;

  -- Return the result
  RETURN result;
EXCEPTION WHEN others THEN
  RETURN jsonb_build_object(
    'error', SQLERRM,
    'detail', SQLSTATE
  );
END;
$$;