/*
  # Verify and fix group data

  1. Changes
    - Add detailed verification of user-group relationships
    - Fix any missing group assignments
    - Add comprehensive logging
*/

-- First, verify user authentication and profiles
DO $$ 
DECLARE
  profile_count integer;
  group_count integer;
BEGIN
  -- Check profiles
  SELECT COUNT(*) INTO profile_count FROM profiles;
  RAISE NOTICE 'Total profiles found: %', profile_count;
  
  -- Check user_groups
  SELECT COUNT(*) INTO group_count FROM user_groups;
  RAISE NOTICE 'Total user_groups found: %', group_count;
  
  -- Log all profile and group relationships
  RAISE NOTICE 'Profile to Group Mappings:';
  FOR r IN (
    SELECT 
      p.id as profile_id,
      p.email,
      ug.group_number,
      ug.user_id as group_user_id
    FROM profiles p
    LEFT JOIN user_groups ug ON p.email = ug.user_id
  ) LOOP
    RAISE NOTICE 'Profile ID: %, Email: %, Group: %, Group User ID: %',
      r.profile_id, r.email, r.group_number, r.group_user_id;
  END LOOP;
  
  -- Verify specific user
  RAISE NOTICE 'Verifying specific user:';
  FOR r IN (
    SELECT 
      p.email,
      ug.group_number,
      p.created_at as profile_created,
      ug.created_at as group_created
    FROM profiles p
    LEFT JOIN user_groups ug ON p.email = ug.user_id
    WHERE p.email = 'mmurphy@getita.net'
  ) LOOP
    RAISE NOTICE 'Email: %, Group: %, Profile Created: %, Group Created: %',
      r.email, r.group_number, r.profile_created, r.group_created;
  END LOOP;
END $$;

-- Ensure the group exists for the specific user
INSERT INTO user_groups (user_id, group_number)
VALUES ('mmurphy@getita.net', 'GRPA')
ON CONFLICT (user_id) 
DO UPDATE SET group_number = EXCLUDED.group_number
RETURNING id, user_id, group_number, created_at;