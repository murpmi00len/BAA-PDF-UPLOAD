CREATE TABLE IF NOT EXISTS baa_bot (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  password text NOT NULL,
  access text NOT NULL,
  "group" text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE baa_bot ENABLE ROW LEVEL SECURITY;

-- Allow users to read records where their email matches the name field
CREATE POLICY "Users can read matching baa_bot records"
  ON baa_bot
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.email = baa_bot.name
    )
  );

-- Allow users to update records where their email matches the name field
CREATE POLICY "Users can update matching baa_bot records"
  ON baa_bot
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.email = baa_bot.name
    )
  );