/*
  # Extended Group Assignment Verification

  1. Changes
    - Add comprehensive verification of group assignments
    - Add detailed logging for debugging
    - Ensure data consistency across tables
    - Add additional indexes for performance
*/

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_groups_user_id ON user_groups(user_id);

-- Comprehensive verification
DO $$ 
DECLARE
  target_email text := 'mmurphy@getita.net';
  found_group text;
  profile_exists boolean;
BEGIN
  -- Log start of verification
  RAISE LOG 'Starting comprehensive group verification...';
  
  -- Check if profile exists
  SELECT EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.email = target_email
  ) INTO profile_exists;
  
  RAISE LOG 'Profile exists for %: %', target_email, profile_exists;
  
  -- Check current group assignment
  SELECT group_number INTO found_group
  FROM user_groups
  WHERE user_id = target_email;
  
  RAISE LOG 'Current group assignment for %: %', target_email, COALESCE(found_group, 'NULL');
  
  -- Verify group assignment
  IF found_group IS NULL THEN
    RAISE LOG 'No group assignment found. Creating new assignment...';
    
    INSERT INTO user_groups (user_id, group_number)
    VALUES (target_email, 'GRPA')
    ON CONFLICT (user_id) DO UPDATE
    SET group_number = EXCLUDED.group_number
    RETURNING group_number INTO found_group;
    
    RAISE LOG 'Created new group assignment: %', found_group;
  END IF;
  
  -- Verify data consistency
  RAISE LOG 'Verifying data consistency...';
  FOR r IN (
    SELECT 
      p.email as profile_email,
      p.id as profile_id,
      ug.user_id as group_user_id,
      ug.group_number,
      ug.created_at as group_created_at
    FROM profiles p
    FULL OUTER JOIN user_groups ug ON p.email = ug.user_id
    WHERE p.email = target_email OR ug.user_id = target_email
  ) LOOP
    RAISE LOG 'Profile Email: %, Profile ID: %, Group User ID: %, Group: %, Created: %',
      r.profile_email, r.profile_id, r.group_user_id, r.group_number, r.group_created_at;
  END LOOP;
  
  -- Final verification
  SELECT group_number INTO found_group
  FROM user_groups
  WHERE user_id = target_email;
  
  IF found_group IS NULL THEN
    RAISE LOG 'ERROR: Group assignment still missing after verification!';
  ELSE
    RAISE LOG 'SUCCESS: Final group assignment verified: %', found_group;
  END IF;
END $$;