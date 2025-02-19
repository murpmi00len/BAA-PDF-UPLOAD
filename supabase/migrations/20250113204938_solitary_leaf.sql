/*
  # Fix Profile Creation

  1. Changes
    - Add immediate profile creation for existing users
    - Add error logging for debugging
  
  2. Security
    - Maintains existing RLS policies
*/

-- Create profiles for any existing users that don't have profiles
INSERT INTO profiles (id, email)
SELECT id, email
FROM auth.users
WHERE NOT EXISTS (
  SELECT 1 FROM profiles WHERE profiles.id = auth.users.id
)
ON CONFLICT (id) DO UPDATE
SET email = EXCLUDED.email,
    last_login = now();

-- Add logging to help debug profile creation issues
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  _error_details text;
BEGIN
  -- Log the attempt
  RAISE LOG 'Attempting to create profile for user: %', new.id;
  
  INSERT INTO public.profiles (id, email)
  VALUES (new.id, new.email)
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      last_login = now();
      
  RAISE LOG 'Successfully created/updated profile for user: %', new.id;
  RETURN new;
EXCEPTION WHEN others THEN
  GET STACKED DIAGNOSTICS _error_details = PG_EXCEPTION_DETAIL;
  RAISE LOG 'Error in handle_new_user for user %: % (%)', new.id, SQLERRM, _error_details;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;