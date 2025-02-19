/*
  # Create BAA-BOT table

  1. New Tables
    - `baa_bot`
      - `id` (uuid, primary key)
      - `name` (text, not null)
      - `password` (text, not null)
      - `access` (text, not null)
      - `group` (text, not null)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on `baa_bot` table
    - Add policies for authenticated users to:
      - Read their own records
      - Update their own records
*/

CREATE TABLE IF NOT EXISTS baa_bot (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  password text NOT NULL,
  access text NOT NULL,
  "group" text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE baa_bot ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own records
CREATE POLICY "Users can read own baa_bot records"
  ON baa_bot
  FOR SELECT
  TO authenticated
  USING (auth.uid()::text = id::text);

-- Allow users to update their own records
CREATE POLICY "Users can update own baa_bot records"
  ON baa_bot
  FOR UPDATE
  TO authenticated
  USING (auth.uid()::text = id::text);