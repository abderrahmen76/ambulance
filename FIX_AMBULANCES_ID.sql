-- ==========================================
-- FIX AMBULANCES ID AUTO-INCREMENT
-- ==========================================
--
-- Issue: ambulances.id column not auto-generating values
-- Error: null value in column "id" violates not-null constraint
--
-- Solution: Recreate the id column as BIGSERIAL with proper sequence

-- STEP 1: Check current ambulances table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'ambulances'
ORDER BY ordinal_position;

-- STEP 2: Get current max id
SELECT MAX(id) as current_max_id FROM public.ambulances;

-- ==========================================
-- STEP 3: Fix the sequence
-- ==========================================

-- Drop existing sequence if it exists
DROP SEQUENCE IF EXISTS public.ambulances_id_seq CASCADE;

-- Create new sequence starting after current max id
CREATE SEQUENCE public.ambulances_id_seq 
  AS BIGINT
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

-- Set the sequence to start after the highest existing id
SELECT setval('public.ambulances_id_seq', COALESCE((SELECT MAX(id) FROM public.ambulances), 0) + 1);

-- Update the id column to use the sequence as default
ALTER TABLE public.ambulances 
ALTER COLUMN id SET DEFAULT nextval('public.ambulances_id_seq'::regclass);

-- Attach sequence ownership
ALTER SEQUENCE public.ambulances_id_seq OWNED BY public.ambulances.id;

-- ==========================================
-- STEP 4: Verify fix
-- ==========================================

-- Check sequence status
SELECT sequence_name, start_value, increment
FROM information_schema.sequences 
WHERE sequence_name = 'ambulances_id_seq';

-- Verify column has default
SELECT column_name, column_default
FROM information_schema.columns
WHERE table_name = 'ambulances' AND column_name = 'id';

-- ==========================================
-- STEP 5: Test - Uncomment to test
-- ==========================================
-- INSERT INTO public.ambulances (ambulance_number, tenant_id, telephone, kilometrage)
-- VALUES ('TEST-AUTO-ID', '62a79092-42a9-4146-adec-e75935fccd69', '999999999', 100.0)
-- RETURNING id, ambulance_number;

