-- Migration: 20261014120000_multi_tenant_data_isolation_fix.sql
-- Description: Complete Multi-Tenant Data Isolation for RPCs and RLS Policies

-- ============================================================================
-- 1. Server-Side Paginated Student Query RPC (Tenant-Isolated)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_student_list(
    p_search TEXT DEFAULT NULL,
    p_branch_id UUID DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 20
)
RETURNS JSONB AS $$
DECLARE
    offset_val INT;
    total_count INT;
    items JSONB;
    v_center_id UUID := public.current_user_center_id();
    v_is_super BOOLEAN := public.is_super_admin();
BEGIN
    offset_val := (GREATEST(1, p_page) - 1) * GREATEST(1, p_page_size);

    SELECT COUNT(*)::int INTO total_count
    FROM public.students s
    JOIN public.profiles p ON p.id = s.profile_id
    WHERE (
        v_is_super OR
        (v_center_id IS NOT NULL AND (
            s.primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id) OR
            p.center_id = v_center_id OR
            EXISTS (SELECT 1 FROM public.center_memberships cm WHERE cm.user_id = s.profile_id AND cm.center_id = v_center_id)
        ))
    )
      AND (p_branch_id IS NULL OR s.primary_branch_id = p_branch_id)
      AND (p_status IS NULL OR s.status = p_status)
      AND (p_search IS NULL OR TRIM(p_search) = '' OR (
          p.full_name ILIKE '%' || p_search || '%' OR
          s.student_code ILIKE '%' || p_search || '%' OR
          p.email ILIKE '%' || p_search || '%'
      ));

    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO items
    FROM (
        SELECT
            s.id,
            s.profile_id,
            s.student_code,
            s.primary_branch_id,
            s.grade_level,
            s.school_name,
            s.status,
            s.created_at,
            p.full_name,
            p.email,
            p.avatar_url,
            p.phone_number
        FROM public.students s
        JOIN public.profiles p ON p.id = s.profile_id
        WHERE (
            v_is_super OR
            (v_center_id IS NOT NULL AND (
                s.primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id) OR
                p.center_id = v_center_id OR
                EXISTS (SELECT 1 FROM public.center_memberships cm WHERE cm.user_id = s.profile_id AND cm.center_id = v_center_id)
            ))
        )
          AND (p_branch_id IS NULL OR s.primary_branch_id = p_branch_id)
          AND (p_status IS NULL OR s.status = p_status)
          AND (p_search IS NULL OR TRIM(p_search) = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              s.student_code ILIKE '%' || p_search || '%' OR
              p.email ILIKE '%' || p_search || '%'
          ))
        ORDER BY p.full_name ASC
        LIMIT p_page_size OFFSET offset_val
    ) item;

    RETURN jsonb_build_object(
        'total', total_count,
        'page', p_page,
        'page_size', p_page_size,
        'data', items
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================================
-- 2. Server-Side Paginated Teacher Query RPC (Tenant-Isolated + Shared Teachers)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_teacher_list(
    p_search TEXT DEFAULT NULL,
    p_branch_id UUID DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 20
)
RETURNS JSONB AS $$
DECLARE
    offset_val INT;
    total_count INT;
    items JSONB;
    v_center_id UUID := public.current_user_center_id();
    v_is_super BOOLEAN := public.is_super_admin();
BEGIN
    offset_val := (GREATEST(1, p_page) - 1) * GREATEST(1, p_page_size);

    SELECT COUNT(*)::int INTO total_count
    FROM public.teachers t
    JOIN public.profiles p ON p.id = t.profile_id
    WHERE (
        v_is_super OR
        (v_center_id IS NOT NULL AND (
            t.primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id) OR
            p.center_id = v_center_id OR
            EXISTS (SELECT 1 FROM public.center_memberships cm WHERE cm.user_id = t.profile_id AND cm.center_id = v_center_id) OR
            EXISTS (
                SELECT 1 FROM public.center_partnerships cp
                JOIN public.center_memberships cm ON (
                    (cm.center_id = cp.partner_center_id AND cp.requester_center_id = v_center_id) OR
                    (cm.center_id = cp.requester_center_id AND cp.partner_center_id = v_center_id)
                )
                WHERE cm.user_id = t.profile_id AND cm.role = 'teacher' AND cp.status = 'approved' AND cp.shared_teachers_enabled = true
            )
        ))
    )
      AND (p_branch_id IS NULL OR t.primary_branch_id = p_branch_id)
      AND (p_search IS NULL OR TRIM(p_search) = '' OR (
          p.full_name ILIKE '%' || p_search || '%' OR
          p.email ILIKE '%' || p_search || '%' OR
          t.specialization ILIKE '%' || p_search || '%'
      ));

    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO items
    FROM (
        SELECT
            t.id,
            t.profile_id,
            t.primary_branch_id,
            t.specialization,
            t.bio,
            t.created_at,
            p.full_name,
            p.email,
            p.avatar_url,
            p.phone_number
        FROM public.teachers t
        JOIN public.profiles p ON p.id = t.profile_id
        WHERE (
            v_is_super OR
            (v_center_id IS NOT NULL AND (
                t.primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id) OR
                p.center_id = v_center_id OR
                EXISTS (SELECT 1 FROM public.center_memberships cm WHERE cm.user_id = t.profile_id AND cm.center_id = v_center_id) OR
                EXISTS (
                    SELECT 1 FROM public.center_partnerships cp
                    JOIN public.center_memberships cm ON (
                        (cm.center_id = cp.partner_center_id AND cp.requester_center_id = v_center_id) OR
                        (cm.center_id = cp.requester_center_id AND cp.partner_center_id = v_center_id)
                    )
                    WHERE cm.user_id = t.profile_id AND cm.role = 'teacher' AND cp.status = 'approved' AND cp.shared_teachers_enabled = true
                )
            ))
        )
          AND (p_branch_id IS NULL OR t.primary_branch_id = p_branch_id)
          AND (p_search IS NULL OR TRIM(p_search) = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.email ILIKE '%' || p_search || '%' OR
              t.specialization ILIKE '%' || p_search || '%'
          ))
        ORDER BY p.full_name ASC
        LIMIT p_page_size OFFSET offset_val
    ) item;

    RETURN jsonb_build_object(
        'total', total_count,
        'page', p_page,
        'page_size', p_page_size,
        'data', items
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================================
-- 3. Server-Side Paginated Parent Query RPC (Tenant-Isolated)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_parent_list(
    p_search TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 20
)
RETURNS JSONB AS $$
DECLARE
    offset_val INT;
    total_count INT;
    items JSONB;
    v_center_id UUID := public.current_user_center_id();
    v_is_super BOOLEAN := public.is_super_admin();
BEGIN
    offset_val := (GREATEST(1, p_page) - 1) * GREATEST(1, p_page_size);

    SELECT COUNT(*)::int INTO total_count
    FROM public.parents pr
    JOIN public.profiles p ON p.id = pr.profile_id
    WHERE (
        v_is_super OR
        (v_center_id IS NOT NULL AND (
            p.center_id = v_center_id OR
            EXISTS (
                SELECT 1 FROM public.student_parents sp
                JOIN public.students s ON s.id = sp.student_id
                WHERE sp.parent_id = pr.id
                  AND (
                      s.primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id) OR
                      s.profile_id IN (SELECT id FROM public.profiles WHERE center_id = v_center_id)
                  )
            )
        ))
    )
      AND (p_search IS NULL OR TRIM(p_search) = '' OR (
          p.full_name ILIKE '%' || p_search || '%' OR
          p.email ILIKE '%' || p_search || '%' OR
          p.phone_number ILIKE '%' || p_search || '%'
      ));

    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO items
    FROM (
        SELECT
            pr.id,
            pr.profile_id,
            pr.occupation,
            pr.status,
            pr.created_at,
            p.full_name,
            p.email,
            p.avatar_url,
            p.phone_number
        FROM public.parents pr
        JOIN public.profiles p ON p.id = pr.profile_id
        WHERE (
            v_is_super OR
            (v_center_id IS NOT NULL AND (
                p.center_id = v_center_id OR
                EXISTS (
                    SELECT 1 FROM public.student_parents sp
                    JOIN public.students s ON s.id = sp.student_id
                    WHERE sp.parent_id = pr.id
                      AND (
                          s.primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id) OR
                          s.profile_id IN (SELECT id FROM public.profiles WHERE center_id = v_center_id)
                      )
                )
            ))
        )
          AND (p_search IS NULL OR TRIM(p_search) = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.email ILIKE '%' || p_search || '%' OR
              p.phone_number ILIKE '%' || p_search || '%'
          ))
        ORDER BY p.full_name ASC
        LIMIT p_page_size OFFSET offset_val
    ) item;

    RETURN jsonb_build_object(
        'total', total_count,
        'page', p_page,
        'page_size', p_page_size,
        'data', items
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================================
-- 4. Academy Core Dashboard Aggregate Summary RPC (Tenant-Isolated)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_academy_core_summary()
RETURNS JSONB AS $$
DECLARE
    v_center_id UUID := public.current_user_center_id();
    v_is_super BOOLEAN := public.is_super_admin();
    b_count INT := 0;
    s_count INT := 0;
    t_count INT := 0;
    sub_count INT := 0;
    g_count INT := 0;
    today_sched_count INT := 0;
    result JSONB;
BEGIN
    IF v_is_super THEN
        SELECT COUNT(*)::int INTO b_count FROM public.branches WHERE status = 'active';
        SELECT COUNT(*)::int INTO s_count FROM public.students WHERE status = 'active';
        SELECT COUNT(*)::int INTO t_count FROM public.teachers;
        SELECT COUNT(*)::int INTO sub_count FROM public.subjects WHERE status = 'active';
        SELECT COUNT(*)::int INTO g_count FROM public.groups WHERE status = 'active';
        SELECT COUNT(*)::int INTO today_sched_count FROM public.schedules WHERE day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::int AND status = 'active';
    ELSIF v_center_id IS NOT NULL THEN
        SELECT COUNT(*)::int INTO b_count FROM public.branches WHERE center_id = v_center_id AND status = 'active';
        SELECT COUNT(*)::int INTO s_count FROM public.students s WHERE (s.primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id) OR s.profile_id IN (SELECT id FROM public.profiles WHERE center_id = v_center_id)) AND status = 'active';
        SELECT COUNT(*)::int INTO t_count FROM public.teachers t WHERE (t.primary_branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id) OR t.profile_id IN (SELECT id FROM public.profiles WHERE center_id = v_center_id) OR EXISTS (SELECT 1 FROM public.center_memberships cm WHERE cm.user_id = t.profile_id AND cm.center_id = v_center_id));
        SELECT COUNT(*)::int INTO sub_count FROM public.subjects WHERE (branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id)) AND status = 'active';
        SELECT COUNT(*)::int INTO g_count FROM public.groups WHERE (branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id)) AND status = 'active';
        SELECT COUNT(*)::int INTO today_sched_count FROM public.schedules sch JOIN public.groups g ON g.id = sch.group_id WHERE g.branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id) AND sch.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::int AND sch.status = 'active';
    END IF;

    result := jsonb_build_object(
        'active_branches', b_count,
        'active_students', s_count,
        'active_teachers', t_count,
        'active_subjects', sub_count,
        'active_groups', g_count,
        'today_scheduled_classes', today_sched_count
    );

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================================
-- 5. Tighten RLS on Core Tables to Prevent Data Leakage
-- ============================================================================

-- Branches: Only see branches belonging to current center
DROP POLICY IF EXISTS "Allow read access to active branches for authenticated users" ON public.branches;
DROP POLICY IF EXISTS "Branches tenant isolation select" ON public.branches;
CREATE POLICY "Branches tenant isolation select"
    ON public.branches FOR SELECT
    TO authenticated
    USING (
        center_id = public.current_user_center_id() OR
        public.is_super_admin()
    );

-- Groups: Only see groups belonging to current center's branches
DROP POLICY IF EXISTS "Allow read access to active groups for authenticated users" ON public.groups;
DROP POLICY IF EXISTS "Groups tenant isolation select" ON public.groups;
CREATE POLICY "Groups tenant isolation select"
    ON public.groups FOR SELECT
    TO authenticated
    USING (
        branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id()) OR
        public.is_super_admin()
    );

-- Subjects: Only see subjects belonging to current center's branches
DROP POLICY IF EXISTS "Allow read access to active subjects for authenticated users" ON public.subjects;
DROP POLICY IF EXISTS "Subjects tenant isolation select" ON public.subjects;
CREATE POLICY "Subjects tenant isolation select"
    ON public.subjects FOR SELECT
    TO authenticated
    USING (
        branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id()) OR
        public.is_super_admin()
    );

-- Schedules: Only see schedules belonging to groups of current center
DROP POLICY IF EXISTS "Allow read access to active schedules for authenticated users" ON public.schedules;
DROP POLICY IF EXISTS "Schedules tenant isolation select" ON public.schedules;
CREATE POLICY "Schedules tenant isolation select"
    ON public.schedules FOR SELECT
    TO authenticated
    USING (
        group_id IN (SELECT id FROM public.groups WHERE branch_id IN (SELECT id FROM public.branches WHERE center_id = public.current_user_center_id())) OR
        public.is_super_admin()
    );

-- Grants
GRANT EXECUTE ON FUNCTION public.get_student_list(TEXT, UUID, TEXT, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_teacher_list(TEXT, UUID, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_parent_list(TEXT, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_academy_core_summary() TO authenticated;

NOTIFY pgrst, 'reload schema';
