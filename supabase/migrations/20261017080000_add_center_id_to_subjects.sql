-- ============================================================================
-- Migration: Add center_id column to public.subjects table safely
-- Purpose: Resolve PostgrestException 42703 (column subjects.center_id does not exist)
-- Date: 2026-10-17
-- ============================================================================

DO $$
BEGIN
    IF to_regclass('public.subjects') IS NOT NULL THEN
        -- Add center_id column if it doesn't already exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
              AND table_name = 'subjects' 
              AND column_name = 'center_id'
        ) THEN
            -- Check if educational_centers table exists for FK constraint
            IF to_regclass('public.educational_centers') IS NOT NULL THEN
                ALTER TABLE public.subjects 
                ADD COLUMN center_id UUID REFERENCES public.educational_centers(id) ON DELETE SET NULL;
            ELSE
                ALTER TABLE public.subjects 
                ADD COLUMN center_id UUID;
            END IF;

            CREATE INDEX IF NOT EXISTS idx_subjects_center_id ON public.subjects(center_id);
            
            -- Backfill center_id from existing branches if both branch_id and branches.center_id exist
            IF EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'public' 
                  AND table_name = 'subjects' 
                  AND column_name = 'branch_id'
            ) AND EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'public' 
                  AND table_name = 'branches' 
                  AND column_name = 'center_id'
            ) THEN
                UPDATE public.subjects s
                SET center_id = b.center_id
                FROM public.branches b
                WHERE s.branch_id = b.id AND s.center_id IS NULL;
            END IF;
        END IF;
    END IF;
END $$;

-- Update RLS policies on public.subjects
DO $$
BEGIN
    IF to_regclass('public.subjects') IS NOT NULL THEN
        -- Drop old isolation policy that might have relied solely on branch_id
        DROP POLICY IF EXISTS "Subjects tenant isolation select" ON public.subjects;
        DROP POLICY IF EXISTS "Subjects tenant isolation modify" ON public.subjects;
        DROP POLICY IF EXISTS "Allow read access to active subjects for authenticated users" ON public.subjects;
        
        -- Create resilient select policy
        CREATE POLICY "Subjects tenant isolation select"
            ON public.subjects FOR SELECT
            TO authenticated
            USING (
                center_id = public.current_user_center_id() OR
                center_id IS NULL OR
                public.is_super_admin()
            );

        -- Create resilient admin modify policy
        CREATE POLICY "Subjects tenant isolation modify"
            ON public.subjects FOR ALL
            TO authenticated
            USING (
                public.current_user_role() IN ('admin', 'super_admin')
            )
            WITH CHECK (
                public.current_user_role() IN ('admin', 'super_admin')
            );
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
