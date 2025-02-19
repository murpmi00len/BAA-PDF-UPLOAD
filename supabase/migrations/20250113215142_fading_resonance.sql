/*
  # Add user group data
  
  1. Changes
    - Insert group data for user
  2. Security
    - No changes to security policies
*/

-- Insert or update user group
INSERT INTO user_groups (user_id, group_number)
VALUES ('mmurphy@getita.net', 'GRPA')
ON CONFLICT (user_id) 
DO UPDATE SET group_number = EXCLUDED.group_number;