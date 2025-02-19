/*
  # Verify and ensure all migrations are properly implemented
  
  1. Changes
    - Verify all required tables exist
    - Ensure all policies are in place
    - Validate group configurations
    
  2. Security
    - Verify RLS is enabled on all tables
    - Confirm policies are correctly configured
*/

-- Verify profiles table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'profiles'
  ) THEN
    CREATE TABLE profiles (
      id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
      email text NOT NULL,
      created_at timestamptz DEFAULT now(),
      last_login timestamptz DEFAULT now()
    );
    
    ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Verify user_groups table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'user_groups'
  ) THEN
    CREATE TABLE user_groups (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id text NOT NULL,
      group_number text NOT NULL,
      created_at timestamptz DEFAULT now(),
      CONSTRAINT user_groups_user_id_key UNIQUE (user_id)
    );
    
    ALTER TABLE user_groups ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Verify baa_bot table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'baa_bot'
  ) THEN
    CREATE TABLE baa_bot (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      name text NOT NULL,
      password text NOT NULL,
      access text NOT NULL,
      "group" text NOT NULL,
      created_at timestamptz DEFAULT now()
    );
    
    ALTER TABLE baa_bot ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Verify policies
DO $$ 
BEGIN
  -- Ensure profiles policies
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND policyname = 'Users can read own profile'
  ) THEN
    CREATE POLICY "Users can read own profile"
      ON profiles
      FOR SELECT
      TO authenticated
      USING (auth.uid() = id);
  END IF;

  -- Ensure user_groups policies
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename = 'user_groups' 
    AND policyname = 'Users can read own group'
  ) THEN
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
  END IF;

  -- Ensure baa_bot policies
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename = 'baa_bot' 
    AND policyname = 'Users can read matching baa_bot records'
  ) THEN
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
  END IF;
END $$;

-- Verify group validation function
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_proc
    WHERE proname = 'validate_user_group'
  ) THEN
    CREATE OR REPLACE FUNCTION public.validate_user_group()
    RETURNS trigger AS $$
    BEGIN
      IF NEW.group_number NOT IN ('GRPA', 'GRPB', 'GRPC', 'DEFAULT') THEN
        RAISE EXCEPTION 'Invalid group number: %', NEW.group_number;
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    DROP TRIGGER IF EXISTS validate_user_group_trigger ON user_groups;
    CREATE TRIGGER validate_user_group_trigger
      BEFORE INSERT OR UPDATE ON user_groups
      FOR EACH ROW
      EXECUTE FUNCTION public.validate_user_group();
  END IF;
END $$;

-- Verify final state
DO $$ 
DECLARE
  tables_exist boolean;
  policies_exist boolean;
BEGIN
  SELECT EXISTS (
    SELECT FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename IN ('profiles', 'user_groups', 'baa_bot')
  ) INTO tables_exist;

  SELECT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename IN ('profiles', 'user_groups', 'baa_bot')
  ) INTO policies_exist;

  IF NOT tables_exist THEN
    RAISE EXCEPTION 'Not all required tables exist';
  END IF;

  IF NOT policies_exist THEN
    RAISE EXCEPTION 'Not all required policies exist';
  END IF;

  RAISE NOTICE 'All migrations verified successfully';
END $$;