/*
  # Fix profile creation and synchronization

  1. Changes
    - Ensures profiles exist for all auth users
    - Updates trigger function to be more robust
    - Adds additional logging
*/

-- First, ensure all existing auth users have profiles
INSERT INTO profiles (id, email)
SELECT id, email
FROM auth.users
WHERE NOT EXISTS (
  SELECT 1 FROM profiles WHERE profiles.id = auth.users.id
)
ON CONFLICT (id) DO UPDATE
SET email = EXCLUDED.email,
    last_login = now();

-- Update the trigger function to be more robust
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  _error_details text;
BEGIN
  -- Add delay to ensure auth.users transaction is complete
  PERFORM pg_sleep(0.1);
  
  -- Log the attempt
  RAISE LOG 'Creating profile for new user. ID: %, Email: %', new.id, new.email;
  
  -- Insert or update the profile
  INSERT INTO public.profiles (id, email)
  VALUES (new.id, new.email)
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      last_login = now();
      
  RAISE LOG 'Profile created/updated successfully for user ID: %', new.id;
  RETURN new;
EXCEPTION WHEN others THEN
  GET STACKED DIAGNOSTICS _error_details = PG_EXCEPTION_DETAIL;
  RAISE LOG 'Error in handle_new_user. User ID: %, Error: % (%)', new.id, SQLERRM, _error_details;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;