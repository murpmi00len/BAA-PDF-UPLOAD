/*
  # Ensure user groups data

  1. Changes
    - Insert or update user groups data for existing users
    - Add specific group assignments
  
  2. Security
    - No changes to existing RLS policies
*/

-- Insert or update user groups with specific assignments
INSERT INTO user_groups (user_id, group_number)
VALUES 
  ('mmurphy@getita.net', 'GRPA'),
  ('test@example.com', 'TEST-GROUP')
ON CONFLICT (user_id) 
DO UPDATE SET group_number = EXCLUDED.group_number;

-- Verify the insertions
DO $$ 
BEGIN
  RAISE NOTICE 'Verifying user_groups data after insertion:';
  FOR r IN (SELECT * FROM user_groups ORDER BY user_id) LOOP
    RAISE NOTICE 'user_id: %, group_number: %', r.user_id, r.group_number;
  END LOOP;
END $$;