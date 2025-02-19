/*
  # Fix group data issues

  1. Changes
    - Add comprehensive data verification
    - Fix any missing group assignments
    - Add detailed logging for debugging
*/

-- First, verify and log the current state
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
  
  -- Log all existing groups
  RAISE NOTICE 'Current user_groups entries:';
  FOR r IN (SELECT * FROM user_groups ORDER BY user_id) LOOP
    RAISE NOTICE 'User ID: %, Group: %', r.user_id, r.group_number;
  END LOOP;

  -- Log all profiles without groups
  RAISE NOTICE 'Profiles without group assignments:';
  FOR r IN (
    SELECT p.email 
    FROM profiles p
    LEFT JOIN user_groups ug ON p.email = ug.user_id
    WHERE ug.id IS NULL
  ) LOOP
    RAISE NOTICE 'Email without group: %', r.email;
  END LOOP;
END $$;

-- Ensure all profiles have group assignments
INSERT INTO user_groups (user_id, group_number)
SELECT p.email, 'DEFAULT'
FROM profiles p
WHERE NOT EXISTS (
  SELECT 1 FROM user_groups ug WHERE ug.user_id = p.email
)
ON CONFLICT (user_id) DO NOTHING;

-- Verify final state
DO $$ 
BEGIN
  RAISE NOTICE 'Final state - Profile to Group mappings:';
  FOR r IN (
    SELECT 
      p.email,
      ug.group_number,
      ug.created_at
    FROM profiles p
    LEFT JOIN user_groups ug ON p.email = ug.user_id
    ORDER BY p.email
  ) LOOP
    RAISE NOTICE 'Email: %, Group: %, Created: %', 
      r.email, r.group_number, r.created_at;
  END LOOP;
END $$;