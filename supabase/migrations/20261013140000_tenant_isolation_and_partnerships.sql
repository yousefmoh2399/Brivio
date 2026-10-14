-- Migration: 20261013140000_tenant_isolation_and_partnerships.sql
-- Description: Airtight Multi-Tenant RLS Data Isolation and Center Partnership Federation Engine

-- ============================================================================
-- 1. Tighten RLS on Branches to Current Active Center
-- ============================================================================
DROP POLICY IF EXISTS "Allow read access to active branches for authenticated users" ON public.branches;
DROP POLICY IF EXISTS "Allow full management of branches to super_admin and admin" ON public.branches;
DROP POLICY IF EXISTS "Branches tenant isolation policy" ON public.branches;

CREATE POLICY "Branches tenant isolation select"
    ON public.branches FOR SELECT
    TO authenticated
    USING (
        center_id = public.current_user_center_id() OR
        public.is_super_admin()
    );

CREATE POLICY "Branches tenant isolation manage"
    ON public.branches FOR ALL
    TO authenticated
    USING (
        (center_id = public.current_user_center_id() AND public.is_admin_or_super()) OR
        public.is_super_admin()
    )
    WITH CHECK (
        (center_id = public.current_user_center_id() AND public.is_admin_or_super()) OR
        public.is_super_admin()
    );

-- ============================================================================
-- 2. Tighten Profiles RLS to Current Active Center
-- ============================================================================
DROP POLICY IF EXISTS "Users can view own profile or branch profiles if staff/admin" ON public.profiles;
DROP POLICY IF EXISTS "Profiles tenant isolation select" ON public.profiles;

CREATE POLICY "Profiles tenant isolation select"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (
        id = auth.uid() OR
        center_id = public.current_user_center_id() OR
        EXISTS (
            SELECT 1 FROM public.center_memberships cm
            WHERE cm.user_id = profiles.id AND cm.center_id = public.current_user_center_id()
        ) OR
        public.is_super_admin()
    );

-- ============================================================================
-- 3. Groups Tenant Isolation
-- ============================================================================
DROP POLICY IF EXISTS "Admins and Staff manage groups" ON public.groups;
DROP POLICY IF EXISTS "Groups tenant isolation manage" ON public.groups;

CREATE POLICY "Groups tenant isolation manage"
    ON public.groups FOR ALL
    TO authenticated
    USING (
        public.is_super_admin() OR
        (
            public.current_user_role() IN ('admin', 'staff') AND
            branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id())
        )
    )
    WITH CHECK (
        public.is_super_admin() OR
        (
            public.current_user_role() IN ('admin', 'staff') AND
            branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id())
        )
    );

-- ============================================================================
-- 4. Students Tenant Isolation
-- ============================================================================
DROP POLICY IF EXISTS "Admins and Staff manage students" ON public.students;
DROP POLICY IF EXISTS "Students tenant isolation manage" ON public.students;

CREATE POLICY "Students tenant isolation manage"
    ON public.students FOR ALL
    TO authenticated
    USING (
        public.is_super_admin() OR
        (
            public.current_user_role() IN ('admin', 'staff') AND
            (
                primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id()) OR
                profile_id IN (SELECT id FROM public.profiles WHERE center_id = public.current_user_center_id()) OR
                profile_id IN (SELECT user_id FROM public.center_memberships WHERE center_id = public.current_user_center_id())
            )
        )
    )
    WITH CHECK (
        public.is_super_admin() OR
        (
            public.current_user_role() IN ('admin', 'staff') AND
            (
                primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id()) OR
                profile_id IN (SELECT id FROM public.profiles WHERE center_id = public.current_user_center_id()) OR
                profile_id IN (SELECT user_id FROM public.center_memberships WHERE center_id = public.current_user_center_id())
            )
        )
    );

-- ============================================================================
-- 5. Teachers Federation & Tenant Isolation
-- (Allows Center Admins to see Center Teachers + Teachers from Approved Partner Centers)
-- ============================================================================
DROP POLICY IF EXISTS "Admins and Staff manage teachers" ON public.teachers;
DROP POLICY IF EXISTS "Teachers tenant isolation manage" ON public.teachers;

CREATE POLICY "Teachers tenant isolation manage"
    ON public.teachers FOR ALL
    TO authenticated
    USING (
        public.is_super_admin() OR
        (
            public.current_user_role() IN ('admin', 'staff') AND
            (
                primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id()) OR
                profile_id IN (
                    SELECT cm.user_id FROM public.center_memberships cm
                    WHERE cm.center_id = public.current_user_center_id() AND cm.role = 'teacher'
                ) OR
                profile_id IN (
                    -- Partner centers shared teachers
                    SELECT cm.user_id FROM public.center_memberships cm
                    JOIN public.center_partnerships cp 
                      ON (cp.partner_center_id = cm.center_id OR cp.requester_center_id = cm.center_id)
                    WHERE cp.status = 'approved' 
                      AND cp.shared_teachers_enabled = true
                      AND (cp.partner_center_id = public.current_user_center_id() OR cp.requester_center_id = public.current_user_center_id())
                      AND cm.role = 'teacher'
                )
            )
        )
    )
    WITH CHECK (
        public.is_super_admin() OR
        (
            public.current_user_role() IN ('admin', 'staff') AND
            (
                primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id()) OR
                profile_id IN (
                    SELECT cm.user_id FROM public.center_memberships cm
                    WHERE cm.center_id = public.current_user_center_id() AND cm.role = 'teacher'
                )
            )
        )
    );

-- ============================================================================
-- 6. Rooms (Classrooms) Tenant Isolation
-- ============================================================================
DROP POLICY IF EXISTS "Rooms tenant isolation all" ON public.rooms;
CREATE POLICY "Rooms tenant isolation all"
    ON public.rooms FOR ALL
    TO authenticated
    USING (
        public.is_super_admin() OR
        branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id())
    )
    WITH CHECK (
        public.is_super_admin() OR
        branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id())
    );

-- ============================================================================
-- 7. Invoices (Finance) Tenant Isolation
-- ============================================================================
DROP POLICY IF EXISTS "Invoices tenant isolation manage" ON public.invoices;
CREATE POLICY "Invoices tenant isolation manage"
    ON public.invoices FOR ALL
    TO authenticated
    USING (
        public.is_super_admin() OR
        (
            public.current_user_role() IN ('admin', 'staff') AND
            student_id IN (
                SELECT s.id FROM public.students s
                WHERE s.primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id())
                   OR s.profile_id IN (SELECT id FROM public.profiles WHERE center_id = public.current_user_center_id())
                   OR s.profile_id IN (SELECT user_id FROM public.center_memberships WHERE center_id = public.current_user_center_id())
            )
        ) OR
        student_id IN (SELECT id FROM public.students WHERE profile_id = auth.uid())
    )
    WITH CHECK (
        public.is_super_admin() OR
        (
            public.current_user_role() IN ('admin', 'staff') AND
            student_id IN (
                SELECT s.id FROM public.students s
                WHERE s.primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id())
                   OR s.profile_id IN (SELECT id FROM public.profiles WHERE center_id = public.current_user_center_id())
                   OR s.profile_id IN (SELECT user_id FROM public.center_memberships WHERE center_id = public.current_user_center_id())
            )
        )
    );

-- ============================================================================
-- 8. RPC: get_center_partnerships
-- Returns incoming and outgoing center partnerships with details
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_center_partnerships()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    u_id UUID := auth.uid();
    v_center_id UUID;
    v_res JSONB;
BEGIN
    IF u_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    v_center_id := public.current_user_center_id();
    IF v_center_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'partnership_id', cp.id,
            'is_requester', (cp.requester_center_id = v_center_id),
            'partner_center_id', CASE WHEN cp.requester_center_id = v_center_id THEN cp.partner_center_id ELSE cp.requester_center_id END,
            'partner_center_name', CASE WHEN cp.requester_center_id = v_center_id THEN p_ctr.name ELSE r_ctr.name END,
            'partner_center_code', CASE WHEN cp.requester_center_id = v_center_id THEN p_ctr.code ELSE r_ctr.code END,
            'partner_phone', CASE WHEN cp.requester_center_id = v_center_id THEN p_ctr.phone_number ELSE r_ctr.phone_number END,
            'partner_governorate', CASE WHEN cp.requester_center_id = v_center_id THEN p_ctr.governorate ELSE r_ctr.governorate END,
            'status', cp.status,
            'shared_teachers_enabled', cp.shared_teachers_enabled,
            'notes', cp.notes,
            'created_at', cp.created_at,
            'updated_at', cp.updated_at
        )
        ORDER BY cp.created_at DESC
    ), '[]'::jsonb)
    INTO v_res
    FROM public.center_partnerships cp
    JOIN public.educational_centers r_ctr ON r_ctr.id = cp.requester_center_id
    JOIN public.educational_centers p_ctr ON p_ctr.id = cp.partner_center_id
    WHERE cp.requester_center_id = v_center_id OR cp.partner_center_id = v_center_id;

    RETURN v_res;
END;
$$;

-- ============================================================================
-- 9. RPC: respond_to_center_partnership
-- Approves or Rejects a partnership request
-- ============================================================================
CREATE OR REPLACE FUNCTION public.respond_to_center_partnership(
    p_partnership_id UUID,
    p_action TEXT -- 'approved', 'rejected', 'terminated'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    u_id UUID := auth.uid();
    v_center_id UUID;
    v_target_partnership RECORD;
    v_clean_action TEXT := LOWER(TRIM(p_action));
BEGIN
    v_center_id := public.current_user_center_id();
    IF v_center_id IS NULL OR NOT public.is_admin_or_super() THEN
        RAISE EXCEPTION 'Only center admins can manage partnerships';
    END IF;

    IF v_clean_action NOT IN ('approved', 'rejected', 'terminated') THEN
        RAISE EXCEPTION 'Invalid action: must be approved, rejected, or terminated';
    END IF;

    SELECT id, requester_center_id, partner_center_id, status
    INTO v_target_partnership
    FROM public.center_partnerships
    WHERE id = p_partnership_id;

    IF v_target_partnership.id IS NULL THEN
        RAISE EXCEPTION 'Partnership request not found';
    END IF;

    -- Only partner center can approve/reject pending request
    IF v_clean_action IN ('approved', 'rejected') AND v_target_partnership.partner_center_id <> v_center_id THEN
        RAISE EXCEPTION 'Only the receiving partner center can accept or reject this request';
    END IF;

    -- Either center can terminate an approved partnership
    IF v_clean_action = 'terminated' AND 
       v_target_partnership.requester_center_id <> v_center_id AND 
       v_target_partnership.partner_center_id <> v_center_id THEN
        RAISE EXCEPTION 'Unauthorized to terminate this partnership';
    END IF;

    UPDATE public.center_partnerships
    SET 
        status = v_clean_action,
        updated_at = NOW()
    WHERE id = p_partnership_id;

    RETURN jsonb_build_object(
        'success', true,
        'partnership_id', p_partnership_id,
        'new_status', v_clean_action
    );
END;
$$;

-- ============================================================================
-- 10. RPC: join_center_by_code
-- Allows student/teacher to link their existing account with a center using its code
-- ============================================================================
CREATE OR REPLACE FUNCTION public.join_center_by_code(p_center_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    u_id UUID := auth.uid();
    v_center RECORD;
    v_user_role user_role;
    v_clean_code TEXT := UPPER(TRIM(p_center_code));
BEGIN
    IF u_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT role INTO v_user_role FROM public.profiles WHERE id = u_id;
    IF v_user_role IS NULL THEN
        v_user_role := 'student';
    END IF;

    SELECT id, name, code, governorate
    INTO v_center
    FROM public.educational_centers
    WHERE code = v_clean_code;

    IF v_center.id IS NULL THEN
        RAISE EXCEPTION 'Center code not found: %', v_clean_code;
    END IF;

    -- Insert or update membership
    INSERT INTO public.center_memberships (
        center_id,
        user_id,
        role,
        status,
        is_primary
    ) VALUES (
        v_center.id,
        u_id,
        v_user_role,
        'active',
        false
    )
    ON CONFLICT (center_id, user_id) 
    DO UPDATE SET status = 'active';

    -- If user has no active center set in profiles, set this as primary
    UPDATE public.profiles
    SET 
        center_id = COALESCE(center_id, v_center.id),
        updated_at = NOW()
    WHERE id = u_id AND (center_id IS NULL);

    RETURN jsonb_build_object(
        'success', true,
        'center_id', v_center.id,
        'center_name', v_center.name,
        'center_code', v_center.code
    );
END;
$$;

-- ============================================================================
-- 11. RPC: get_current_center_stats
-- Returns overview statistics for the current active center
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_current_center_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_center_id UUID;
    v_center_rec RECORD;
    v_branches_cnt INT := 0;
    v_students_cnt INT := 0;
    v_teachers_cnt INT := 0;
    v_groups_cnt INT := 0;
    v_partnerships_cnt INT := 0;
BEGIN
    v_center_id := public.current_user_center_id();
    IF v_center_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active center');
    END IF;

    SELECT id, name, code, phone_number, governorate, subscription_status, subscription_tier
    INTO v_center_rec
    FROM public.educational_centers
    WHERE id = v_center_id;

    -- Count branches
    SELECT COUNT(*) INTO v_branches_cnt
    FROM public.branches
    WHERE center_id = v_center_id AND status = 'active';

    -- Count students
    SELECT COUNT(DISTINCT s.id) INTO v_students_cnt
    FROM public.students s
    LEFT JOIN public.branches b ON b.id = s.primary_branch_id
    LEFT JOIN public.profiles p ON p.id = s.profile_id
    WHERE b.center_id = v_center_id 
       OR p.center_id = v_center_id
       OR EXISTS (SELECT 1 FROM public.center_memberships cm WHERE cm.user_id = p.id AND cm.center_id = v_center_id);

    -- Count teachers (memberships or direct)
    SELECT COUNT(DISTINCT user_id) INTO v_teachers_cnt
    FROM public.center_memberships
    WHERE center_id = v_center_id AND role = 'teacher' AND status = 'active';

    -- Count active groups
    SELECT COUNT(DISTINCT g.id) INTO v_groups_cnt
    FROM public.groups g
    JOIN public.branches b ON b.id = g.branch_id
    WHERE b.center_id = v_center_id AND g.status = 'active';

    -- Count approved partnerships
    SELECT COUNT(*) INTO v_partnerships_cnt
    FROM public.center_partnerships
    WHERE (requester_center_id = v_center_id OR partner_center_id = v_center_id)
      AND status = 'approved';

    RETURN jsonb_build_object(
        'success', true,
        'center_id', v_center_rec.id,
        'center_name', v_center_rec.name,
        'center_code', v_center_rec.code,
        'governorate', v_center_rec.governorate,
        'phone_number', v_center_rec.phone_number,
        'subscription_tier', v_center_rec.subscription_tier,
        'subscription_status', v_center_rec.subscription_status,
        'stats', jsonb_build_object(
            'branches_count', v_branches_cnt,
            'students_count', v_students_cnt,
            'teachers_count', v_teachers_cnt,
            'groups_count', v_groups_cnt,
            'partnerships_count', v_partnerships_cnt
        )
    );
END;
$$;

-- Grants
GRANT EXECUTE ON FUNCTION public.get_center_partnerships() TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_center_partnership(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_center_by_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_center_stats() TO authenticated;

NOTIFY pgrst, 'reload schema';
