-- Fix: Add enrolled_at column to enrollments table
ALTER TABLE public.enrollments
  ADD COLUMN IF NOT EXISTS enrolled_at TIMESTAMPTZ DEFAULT NOW();

UPDATE public.enrollments
  SET enrolled_at = COALESCE(created_at, start_date::timestamptz, NOW())
  WHERE enrolled_at IS NULL;
