/*
  # Create User Groups Table

  1. New Tables
    - `user_groups`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references profiles)
      - `group_number` (text)
      - `created_at` (timestamp)
  
  2. Security
    - Enable RLS on `user_groups` table
    - Add policy for users to read their own group
*/

CREATE TABLE IF NOT EXISTS user_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  group_number text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE user_groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own group"
  ON user_groups
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);