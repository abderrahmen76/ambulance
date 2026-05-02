-- Create custom_clinics table
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS custom_clinics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_custom_clinics_name ON custom_clinics(clinic_name);

-- Add RLS policy to allow public read access
ALTER TABLE custom_clinics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access" ON custom_clinics
  FOR SELECT USING (true);

CREATE POLICY "Allow public insert access" ON custom_clinics
  FOR INSERT WITH CHECK (true);

-- Note: clinic_name is UNIQUE to prevent duplicates
-- If a duplicate clinic is attempted, the insert will fail gracefully
