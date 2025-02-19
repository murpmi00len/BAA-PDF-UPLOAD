/*
  # Fix group assignments and verify data integrity

  1. Changes
    - Verify and clean up any duplicate entries
    - Ensure proper group assignments
    - Add logging for debugging purposes

  2. Security
    - Maintains existing RLS policies
*/

-- Clean up any potential duplicate entries
DELETE FROM user_groups a USING (
  SELECT MIN(id) as id, user_id
  FROM user_groups 
  GROUP BY user_id
  HAVING COUNT(*) > 1
) b
WHERE a.user_id = b.user_id 
AND a.id <> b.id;

-- Ensure specific group assignments exist
INSERT INTO user_groups (user_id, group_number)
VALUES 
  ('mmurphy@getita.net', 'GRPA')
ON CONFLICT (user_id) 
DO UPDATE SET group_number = EXCLUDED.group_number;

-- Verify the data state
DO $$ 
DECLARE
  user_email text := 'mmurphy@getita.net';
  user_group text;
BEGIN
  -- Check specific user's group
  SELECT group_number INTO user_group
  FROM user_groups
  WHERE user_id = user_email;
  
  IF user_group IS NULL THEN
    RAISE LOG 'No group found for user: %', user_email;
  ELSE
    RAISE LOG 'User % has group: %', user_email, user_group;
  END IF;
  
  -- Log all current group assignments
  RAISE LOG 'Current group assignments:';
  FOR r IN (
    SELECT user_id, group_number
    FROM user_groups
    ORDER BY user_id
  ) LOOP
    RAISE LOG 'User: %, Group: %', r.user_id, r.group_number;
  END LOOP;
END $$;