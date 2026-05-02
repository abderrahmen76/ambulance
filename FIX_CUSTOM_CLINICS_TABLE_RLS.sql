-- CRITICAL FIX: Add city column to custom_clinics and fix RLS for driver access
-- Problem: custom_clinics table missing 'city' column; id default not working via REST API
-- Solution: Add city column, recreate id column properly, and create driver-friendly RLS INSERT policy

-- DROP the old custom_clinics table and recreate with proper UUID generation
DROP TABLE IF EXISTS custom_clinics CASCADE;

-- Recreate table with proper UUID generation
CREATE TABLE custom_clinics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_name VARCHAR(255) NOT NULL,
  city VARCHAR(255) NOT NULL DEFAULT 'Sfax',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(clinic_name, city)  -- Prevent duplicate clinic names for same city
);

-- Add indexes for faster queries
CREATE INDEX idx_custom_clinics_name ON custom_clinics(clinic_name);
CREATE INDEX idx_custom_clinics_city ON custom_clinics(city);
CREATE INDEX idx_custom_clinics_city_name ON custom_clinics(city, clinic_name);

-- Enable RLS (must do this before creating policies)
ALTER TABLE custom_clinics ENABLE ROW LEVEL SECURITY;

-- Drop the overly permissive policies if they exist
DROP POLICY IF EXISTS "Allow public read access" ON custom_clinics;
DROP POLICY IF EXISTS "Allow public insert access" ON custom_clinics;

-- New policy: Anyone can READ custom clinics
CREATE POLICY "custom_clinics select"
ON custom_clinics FOR SELECT
USING (true);

-- New policy: AUTHENTICATED USERS (drivers, managers, admins) can INSERT
-- This allows drivers to add custom clinics for their city
CREATE POLICY "custom_clinics insert"
ON custom_clinics FOR INSERT
WITH CHECK (
  -- Must be authenticated
  auth.uid() IS NOT NULL
  -- Clinic name must not be empty
  AND clinic_name != ''
  -- Clinic name must not be reserved keyword
  AND clinic_name != 'Autre (Ajouter une nouvelle)'
);

-- New policy: Only managers/admins can UPDATE or DELETE
CREATE POLICY "custom_clinics update"
ON custom_clinics FOR UPDATE
USING (
  (SELECT role FROM public.users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
)
WITH CHECK (
  (SELECT role FROM public.users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
);

CREATE POLICY "custom_clinics delete"
ON custom_clinics FOR DELETE
USING (
  (SELECT role FROM public.users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
);

-- Verify policies were created
SELECT * FROM pg_policies WHERE tablename = 'custom_clinics' ORDER BY policyname;
