-- Migration: 20261015143000_fix_multi_tenant_summaries_and_parents.sql
-- Description: Fix get_parent_list (parent_students table typo) and restore tenant isolation to get_academy_core_summary

-- ============================================================================
-- 1. Fix get_parent_list RPC (Correct table name: parent_students)
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
                SELECT 1 FROM public.parent_students sp
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
                    SELECT 1 FROM public.parent_students sp
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

GRANT EXECUTE ON FUNCTION public.get_parent_list(TEXT, INT, INT) TO authenticated;

-- ============================================================================
-- 2. Restore Tenant Isolation to get_academy_core_summary()
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

GRANT EXECUTE ON FUNCTION public.get_academy_core_summary() TO authenticated, anon;
