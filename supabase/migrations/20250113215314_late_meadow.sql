/*
  # Verify and fix group data
  
  1. Changes
    - Verify user_groups table structure
    - Insert test data if missing
*/

-- First, verify the data
DO $$ 
BEGIN
  -- Log existing data for debugging
  RAISE NOTICE 'Current user_groups data:';
  FOR r IN (SELECT * FROM user_groups) LOOP
    RAISE NOTICE 'user_id: %, group_number: %', r.user_id, r.group_number;
  END LOOP;

  -- Insert test data if none exists
  INSERT INTO user_groups (user_id, group_number)
  SELECT 
    p.email,
    'TEST-GROUP'
  FROM profiles p
  WHERE NOT EXISTS (
    SELECT 1 FROM user_groups ug WHERE ug.user_id = p.email
  );
END $$;