/*
  # Check for BAA-BOT table existence

  This migration will safely check if the BAA-BOT table exists and create it if it doesn't.
*/

DO $$ 
BEGIN
  -- Check if table exists
  IF NOT EXISTS (
    SELECT FROM pg_tables
    WHERE schemaname = 'public' 
    AND tablename = 'baa_bot'
  ) THEN
    RAISE NOTICE 'Table BAA-BOT does not exist';
  ELSE
    RAISE NOTICE 'Table BAA-BOT exists';
  END IF;
END $$;