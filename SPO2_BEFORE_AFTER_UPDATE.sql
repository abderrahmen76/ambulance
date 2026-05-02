-- Add spo2_before and spo2_after columns to missions table
-- Replaces the single spo2 field with before/after measurements
-- Updates to vital_signs JSON structure to use spo2_before and spo2_after

-- If you have a vital_signs JSON column, add the two new columns:
ALTER TABLE public.missions
ADD COLUMN spo2_before TEXT,
ADD COLUMN spo2_after TEXT;

-- Add comments to document the columns
COMMENT ON COLUMN public.missions.spo2_before IS 'SpO2 (Oxygen saturation) reading BEFORE treatment';
COMMENT ON COLUMN public.missions.spo2_after IS 'SpO2 (Oxygen saturation) reading AFTER treatment';

-- If you want to migrate existing spo2 data to spo2_before (optional):
-- UPDATE public.missions 
-- SET spo2_before = CAST(vital_signs->>'spo2' AS TEXT)
-- WHERE vital_signs->>'spo2' IS NOT NULL AND spo2_before IS NULL;

-- Then remove the old spo2 field from vital_signs JSON in future queries
