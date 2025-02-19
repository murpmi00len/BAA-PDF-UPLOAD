/*
  # Fix user groups table structure

  1. Changes
    - Drop existing user_groups table
    - Recreate with proper email-based lookup
    - Add appropriate policies
*/

-- Drop the existing table
DROP TABLE IF EXISTS user_groups;

-- Create the table with email-based user_id
CREATE TABLE IF NOT EXISTS user_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  group_number text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE user_groups ENABLE ROW LEVEL SECURITY;

-- Create policy for reading groups
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