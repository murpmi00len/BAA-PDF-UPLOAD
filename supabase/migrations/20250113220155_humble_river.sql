/*
  # Debug user groups and ensure data integrity

  1. Changes
    - Add detailed logging of existing data
    - Verify user_groups table structure
    - Ensure test data exists
    - Add debugging information
*/

-- Log table structure
DO $$ 
BEGIN
  RAISE NOTICE 'Checking user_groups table structure:';
  FOR r IN (
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_name = 'user_groups'
  ) LOOP
    RAISE NOTICE 'Column: %, Type: %, Nullable: %', r.column_name, r.data_type, r.is_nullable;
  END LOOP;
END $$;

-- Log existing data
DO $$ 
BEGIN
  RAISE NOTICE 'Current user_groups data:';
  FOR r IN (SELECT * FROM user_groups) LOOP
    RAISE NOTICE 'ID: %, User ID: %, Group: %, Created: %', 
      r.id, r.user_id, r.group_number, r.created_at;
  END LOOP;
END $$;

-- Log existing profiles
DO $$ 
BEGIN
  RAISE NOTICE 'Current profiles data:';
  FOR r IN (SELECT * FROM profiles) LOOP
    RAISE NOTICE 'ID: %, Email: %, Created: %', 
      r.id, r.email, r.created_at;
  END LOOP;
END $$;

-- Ensure specific test data exists
INSERT INTO user_groups (user_id, group_number)
VALUES ('mmurphy@getita.net', 'GRPA')
ON CONFLICT (user_id) 
DO UPDATE SET group_number = EXCLUDED.group_number;

-- Verify final state
DO $$ 
BEGIN
  RAISE NOTICE 'Final verification - user_groups data:';
  FOR r IN (
    SELECT ug.*, p.email as profile_email
    FROM user_groups ug
    LEFT JOIN profiles p ON p.email = ug.user_id
  ) LOOP
    RAISE NOTICE 'User ID: %, Group: %, Profile Email: %', 
      r.user_id, r.group_number, r.profile_email;
  END LOOP;
END $$;