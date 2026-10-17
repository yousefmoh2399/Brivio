-- Migration: 20261017103000_parent_real_data_and_homework_feed.sql
-- Description: Provide parent-accessible homework feed, student gamification summary by student ID,
-- and extend RLS policies so guardians can view student homework submissions.

-- 1. Homework Submissions RLS Policy for Parents
DROP POLICY IF EXISTS "Homework submissions viewable by self and teachers" ON public.homework_submissions;
CREATE POLICY "Homework submissions viewable by self and teachers" 
ON public.homework_submissions FOR SELECT TO authenticated 
USING (
    public.is_admin_or_super() 
    OR EXISTS (SELECT 1 FROM public.students s WHERE s.id = homework_submissions.student_id AND s.profile_id = auth.uid())
    OR public.parent_can_access_student(homework_submissions.student_id)
    OR EXISTS (
        SELECT 1 FROM public.homework hw 
        WHERE hw.id = homework_submissions.homework_id AND public.current_teacher_assigned_to_group(hw.group_id)
    )
);

-- 2. Real Homework Feed for Parent Portal
CREATE OR REPLACE FUNCTION public.get_parent_child_homework_feed(p_student_id UUID)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  subject_id UUID,
  subject_name TEXT,
  group_id UUID,
  group_name TEXT,
  due_at TIMESTAMPTZ,
  max_score NUMERIC,
  status TEXT,
  submission_status TEXT,
  score NUMERIC,
  submitted_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.parent_can_access_student(p_student_id)
    OR public.current_student_id() = p_student_id
    OR public.is_admin_or_super()
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Parent account is not linked to this student' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    hw.id,
    COALESCE(hw.title, 'واجب دراسي')::TEXT AS title,
    COALESCE(hw.description, '')::TEXT AS description,
    hw.subject_id,
    COALESCE(sub.name, 'مادة دراسية')::TEXT AS subject_name,
    hw.group_id,
    COALESCE(g.name, 'المجموعة')::TEXT AS group_name,
    hw.due_at,
    COALESCE(hw.max_score, 100.0)::NUMERIC AS max_score,
    hw.status::TEXT AS status,
    CASE
      WHEN hs.status = 'graded' THEN 'graded'
      WHEN hs.status = 'submitted' THEN 'submitted'
      WHEN hw.due_at < NOW() AND (hs.status IS NULL OR hs.status = 'in_progress') THEN 'missing'
      ELSE 'pending'
    END::TEXT AS submission_status,
    hs.score::NUMERIC AS score,
    hs.submitted_at
  FROM public.homework hw
  JOIN public.enrollments e ON e.group_id = hw.group_id AND e.student_id = p_student_id AND e.status = 'active'
  LEFT JOIN public.groups g ON g.id = hw.group_id
  LEFT JOIN public.subjects sub ON sub.id = hw.subject_id
  LEFT JOIN public.homework_submissions hs ON hs.homework_id = hw.id AND hs.student_id = p_student_id
  WHERE hw.status = 'published'
  ORDER BY hw.due_at DESC;
END;
$$;

-- 3. Student Gamification Summary Accessible by Student ID (supports parents)
CREATE OR REPLACE FUNCTION public.get_student_gamification_summary(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    s_id UUID := COALESCE(p_student_id, public.current_student_id());
    total_xp INT := 0;
    badge_count INT := 0;
    last_xp TIMESTAMPTZ;
    level_no INT := 1;
    level_floor INT := 0;
    level_progress INT := 0;
    xp_to_next INT := 500;
    streak_days INT := 0;
    expected_day DATE;
    day_row DATE;
    badges_json JSONB := '[]'::jsonb;
BEGIN
    IF s_id IS NULL THEN
        RAISE EXCEPTION 'Student ID is required' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        public.parent_can_access_student(s_id)
        OR public.current_student_id() = s_id
        OR public.is_admin_or_super()
        OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    ) THEN
        RAISE EXCEPTION 'Unauthorized to view student gamification' USING ERRCODE = '42501';
    END IF;

    SELECT
        COALESCE(SUM(xp_amount), 0)::INT,
        MAX(created_at)
    INTO total_xp, last_xp
    FROM public.student_xp_events
    WHERE student_id = s_id;

    SELECT COUNT(*)::INT
    INTO badge_count
    FROM public.student_badges
    WHERE student_id = s_id;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'name', b.name,
                'code', b.code,
                'awarded_at', sb.awarded_at,
                'xp_reward', b.xp_reward
            )
            ORDER BY sb.awarded_at DESC
        ),
        '[]'::jsonb
    )
    INTO badges_json
    FROM public.student_badges sb
    JOIN public.gamification_badges b ON b.id = sb.badge_id
    WHERE sb.student_id = s_id;

    level_no := GREATEST(1, FLOOR(total_xp / 500)::INT + 1);
    level_floor := (level_no - 1) * 500;
    xp_to_next := GREATEST(0, (level_no * 500) - total_xp);
    level_progress := GREATEST(0, LEAST(100, FLOOR(((total_xp - level_floor)::NUMERIC / 500) * 100)::INT));

    IF last_xp IS NOT NULL THEN
        expected_day := CASE
            WHEN last_xp::DATE >= CURRENT_DATE THEN CURRENT_DATE
            WHEN last_xp::DATE = CURRENT_DATE - 1 THEN CURRENT_DATE - 1
            ELSE NULL
        END;

        IF expected_day IS NOT NULL THEN
            FOR day_row IN
                SELECT DISTINCT created_at::DATE AS xp_day
                FROM public.student_xp_events
                WHERE student_id = s_id
                ORDER BY xp_day DESC
            LOOP
                IF day_row = expected_day THEN
                    streak_days := streak_days + 1;
                    expected_day := expected_day - 1;
                ELSIF day_row < expected_day THEN
                    EXIT;
                END IF;
            END LOOP;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'student_id', s_id,
        'total_xp', total_xp,
        'level', level_no,
        'level_progress', level_progress,
        'xp_to_next_level', xp_to_next,
        'streak_days', streak_days,
        'badge_count', badge_count,
        'badges', badges_json
    );
END;
$$;

-- 4. Permissions
REVOKE EXECUTE ON FUNCTION public.get_parent_child_homework_feed(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_parent_child_homework_feed(UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_student_gamification_summary(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_student_gamification_summary(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
