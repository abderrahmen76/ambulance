-- Add ambulancier_name column to equipment_rentals table
-- This migration adds a field to track the ambulance driver/staff member name
-- for each equipment rental

ALTER TABLE public.equipment_rentals
ADD COLUMN ambulancier_name TEXT NOT NULL DEFAULT '';

-- Add comment to document the column
COMMENT ON COLUMN public.equipment_rentals.ambulancier_name IS 'Name of the ambulance driver or staff member associated with this equipment rental';
