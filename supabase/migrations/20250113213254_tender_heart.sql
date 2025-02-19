/*
  # Update user_groups table policies

  1. Changes
    - Add policy to allow authenticated users to read all groups
    - Keep existing policy as fallback
  
  2. Security
    - Maintains RLS but adds more permissive read access for testing
*/

-- Add a new policy for reading all groups
CREATE POLICY "Authenticated users can read all groups"
  ON user_groups
  FOR SELECT
  TO authenticated
  USING (true);