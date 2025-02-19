/*
  # Add unique constraint to user_groups table

  1. Changes
    - Add UNIQUE constraint to user_id column in user_groups table
    
  2. Purpose
    - Enable upsert operations using ON CONFLICT
    - Ensure each user can only have one group assignment
*/

ALTER TABLE user_groups
ADD CONSTRAINT user_groups_user_id_key UNIQUE (user_id);