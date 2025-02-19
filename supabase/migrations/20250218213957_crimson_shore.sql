/*
  # Restore and update grouping configuration

  1. Changes
    - Add user group validation function
    - Add group assignment trigger
    - Update RLS policies for user_groups table
    
  2. Security
    - Enable RLS
    - Add policies for authenticated users
*/

-- Create function to validate user group
CREATE OR REPLACE FUNCTION public.validate_user_group()
RETURNS trigger AS $$
BEGIN
  -- Ensure group number is valid
  IF NEW.group_number NOT IN ('GRPA', 'GRPB', 'GRPC', 'DEFAULT') THEN
    RAISE EXCEPTION 'Invalid group number: %', NEW.group_number;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for group validation
DROP TRIGGER IF EXISTS validate_user_group_trigger ON user_groups;
CREATE TRIGGER validate_user_group_trigger
  BEFORE INSERT OR UPDATE ON user_groups
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_user_group();

-- Update RLS policies
ALTER TABLE user_groups ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can read own group" ON user_groups;
DROP POLICY IF EXISTS "Authenticated users can read all groups" ON user_groups;

-- Create new policies
CREATE POLICY "Users can read own group"
  ON user_groups
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.email = user_groups.user_id
    )
  );

CREATE POLICY "Users can update own group"
  ON user_groups
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.email = user_groups.user_id
    )
  );

-- Function to get user's group
CREATE OR REPLACE FUNCTION public.get_user_group(user_email text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  group_number text;
BEGIN
  SELECT ug.group_number INTO group_number
  FROM user_groups ug
  WHERE ug.user_id = user_email;
  
  RETURN COALESCE(group_number, 'DEFAULT');
END;
$$;