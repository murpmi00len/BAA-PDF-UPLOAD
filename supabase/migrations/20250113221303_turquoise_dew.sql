/*
  # Verify and ensure group assignments

  1. Changes
    - Verify existing group assignments
    - Add additional logging for debugging
    - Ensure data consistency
*/

-- Verify existing data and add detailed logging
DO $$ 
DECLARE
  target_email text := 'mmurphy@getita.net';
  found_group text;
BEGIN
  -- Check if the user_groups table exists and has the correct structure
  RAISE LOG 'Verifying user_groups table structure...';
  
  -- Check for our target user's group
  SELECT group_number INTO found_group
  FROM user_groups
  WHERE user_id = target_email;
  
  IF found_group IS NULL THEN
    RAISE LOG 'Target user group not found. Attempting to create...';
    
    -- Insert the group if it doesn't exist
    INSERT INTO user_groups (user_id, group_number)
    VALUES (target_email, 'GRPA')
    ON CONFLICT (user_id) DO UPDATE
    SET group_number = EXCLUDED.group_number
    RETURNING group_number INTO found_group;
    
    RAISE LOG 'Created group assignment: %', found_group;
  ELSE
    RAISE LOG 'Found existing group assignment: %', found_group;
  END IF;
  
  -- Verify final state
  RAISE LOG 'Final verification of group assignments:';
  FOR r IN (
    SELECT ug.user_id, ug.group_number, p.email
    FROM user_groups ug
    LEFT JOIN profiles p ON p.email = ug.user_id
    ORDER BY ug.user_id
  ) LOOP
    RAISE LOG 'User: %, Group: %, Profile Email: %', 
      r.user_id, r.group_number, r.email;
  END LOOP;
END $$;