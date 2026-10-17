-- Migration: 20261017110000_parent_schedule_real_data_and_robust_joins.sql
-- Description: Robust schedule resolution for students and parents with null-safe joins and guardian permissions.

-- 1. RLS Policies on schedules and class_sessions for parents
DROP POLICY IF EXISTS "Schedules viewable by parents of enrolled students" ON public.schedules;
CREATE POLICY "Schedules viewable by parents of enrolled students"
ON public.schedules FOR SELECT TO authenticated USING (
  public.is_admin_or_super()
  OR EXISTS (
    SELECT 1 FROM public.enrollments e
    WHERE e.group_id = schedules.group_id
      AND (
        e.student_id = public.current_student_id()
        OR public.parent_can_access_student(e.student_id)
        OR public.current_parent_has_student(e.student_id)
      )
  )
);

DROP POLICY IF EXISTS "Class sessions viewable by parents of enrolled students" ON public.class_sessions;
CREATE POLICY "Class sessions viewable by parents of enrolled students"
ON public.class_sessions FOR SELECT TO authenticated USING (
  public.is_admin_or_super()
  OR EXISTS (
    SELECT 1 FROM public.enrollments e
    WHERE e.group_id = class_sessions.group_id
      AND (
        e.student_id = public.current_student_id()
        OR public.parent_can_access_student(e.student_id)
        OR public.current_parent_has_student(e.student_id)
      )
  )
);

-- 2. Enhanced get_student_schedule with robust joins and null-safety
DROP FUNCTION IF EXISTS public.get_parent_child_schedule(UUID, DATE, DATE);
DROP FUNCTION IF EXISTS public.get_student_schedule(UUID, DATE, DATE);

CREATE OR REPLACE FUNCTION public.get_student_schedule(
  p_student_id UUID,
  p_from_date DATE DEFAULT CURRENT_DATE,
  p_to_date DATE DEFAULT (CURRENT_DATE + INTERVAL '30 days')::DATE
)
RETURNS TABLE (
  source_type TEXT,
  enrollment_id UUID,
  access_status TEXT,
  payment_status TEXT,
  group_id UUID,
  group_name TEXT,
  subject_id UUID,
  subject_name TEXT,
  branch_id UUID,
  branch_name TEXT,
  schedule_id UUID,
  class_session_id UUID,
  session_date DATE,
  day_of_week INT,
  start_time TIME,
  end_time TIME,
  scheduled_start_at TIMESTAMPTZ,
  scheduled_end_at TIMESTAMPTZ,
  status TEXT,
  room_id UUID,
  room_code TEXT,
  room_name TEXT,
  location TEXT,
  teacher_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID;
BEGIN
  SELECT s.id INTO v_student_id
  FROM public.students s
  WHERE s.id = p_student_id OR s.profile_id = p_student_id
  LIMIT 1;

  IF v_student_id IS NULL THEN
    v_student_id := p_student_id;
  END IF;

  IF p_to_date < p_from_date OR (p_to_date - p_from_date) > 180 THEN
    RAISE EXCEPTION 'Invalid date range for schedule lookup (max 180 days)' USING ERRCODE = '22023';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('schedules.view')
    OR public.has_permission('enrollments.view')
    OR public.parent_can_access_student(v_student_id)
    OR public.current_parent_has_student(v_student_id)
    OR EXISTS (SELECT 1 FROM public.students s WHERE s.id = v_student_id AND s.profile_id = auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.enrollments e
      WHERE e.student_id = v_student_id
        AND public.current_teacher_assigned_to_group(e.group_id)
    )
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view student schedule' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH active_enrollments AS (
    SELECT 
      e.id AS enrollment_id, 
      e.student_id, 
      e.group_id, 
      COALESCE(e.access_status::TEXT, 'granted') AS access_status, 
      COALESCE(e.payment_status::TEXT, 'paid') AS payment_status
    FROM public.enrollments e
    WHERE e.student_id = v_student_id
      AND (e.status = 'active' OR e.status IS NULL)
      AND (e.start_date IS NULL OR e.start_date <= p_to_date)
      AND (e.end_date IS NULL OR e.end_date >= p_from_date)
  ),
  session_rows AS (
    SELECT
      'session'::TEXT AS source_type,
      ae.enrollment_id,
      ae.access_status,
      ae.payment_status,
      g.id AS group_id,
      COALESCE(g.name, 'مجموعة دراسية')::TEXT AS group_name,
      g.subject_id,
      COALESCE(sub.name, g.subject, 'حصة دراسية')::TEXT AS subject_name,
      g.branch_id,
      COALESCE(b.name, 'الفرع الرئيسي')::TEXT AS branch_name,
      cs.schedule_id,
      cs.id AS class_session_id,
      cs.session_date,
      COALESCE(cs.day_of_week, EXTRACT(ISODOW FROM cs.session_date)::INT) AS day_of_week,
      cs.scheduled_start_at::TIME AS start_time,
      cs.scheduled_end_at::TIME AS end_time,
      cs.scheduled_start_at,
      cs.scheduled_end_at,
      COALESCE(cs.status, 'scheduled')::TEXT AS status,
      cs.room_id,
      r.code AS room_code,
      r.name AS room_name,
      COALESCE(cs.location, r.name, 'القاعة الرئيسية')::TEXT AS location,
      COALESCE(tp.full_name, 'معلم المادة')::TEXT AS teacher_name
    FROM active_enrollments ae
    JOIN public.groups g ON g.id = ae.group_id
    LEFT JOIN public.subjects sub ON sub.id = g.subject_id
    LEFT JOIN public.branches b ON b.id = g.branch_id
    LEFT JOIN public.teachers t ON t.id = g.teacher_id
    LEFT JOIN public.profiles tp ON tp.id = t.profile_id
    JOIN public.class_sessions cs ON cs.group_id = g.id
    LEFT JOIN public.rooms r ON r.id = cs.room_id
    WHERE cs.session_date BETWEEN p_from_date AND p_to_date
  ),
  schedule_occurrences AS (
    SELECT
      'schedule'::TEXT AS source_type,
      ae.enrollment_id,
      ae.access_status,
      ae.payment_status,
      g.id AS group_id,
      COALESCE(g.name, 'مجموعة دراسية')::TEXT AS group_name,
      g.subject_id,
      COALESCE(sub.name, g.subject, 'حصة دراسية')::TEXT AS subject_name,
      g.branch_id,
      COALESCE(b.name, 'الفرع الرئيسي')::TEXT AS branch_name,
      sch.id AS schedule_id,
      NULL::UUID AS class_session_id,
      gs.day_value::DATE AS session_date,
      sch.day_of_week,
      sch.start_time,
      sch.end_time,
      (gs.day_value::DATE || ' ' || sch.start_time)::TIMESTAMPTZ AS scheduled_start_at,
      (gs.day_value::DATE || ' ' || sch.end_time)::TIMESTAMPTZ AS scheduled_end_at,
      COALESCE(sch.status, 'active')::TEXT AS status,
      sch.room_id,
      r.code AS room_code,
      r.name AS room_name,
      COALESCE(sch.location, r.name, 'القاعة الرئيسية')::TEXT AS location,
      COALESCE(tp.full_name, 'معلم المادة')::TEXT AS teacher_name
    FROM active_enrollments ae
    JOIN public.groups g ON g.id = ae.group_id
    LEFT JOIN public.subjects sub ON sub.id = g.subject_id
    LEFT JOIN public.branches b ON b.id = g.branch_id
    LEFT JOIN public.teachers t ON t.id = g.teacher_id
    LEFT JOIN public.profiles tp ON tp.id = t.profile_id
    JOIN public.schedules sch ON sch.group_id = g.id AND (sch.status = 'active' OR sch.status IS NULL)
    CROSS JOIN generate_series(p_from_date, p_to_date, INTERVAL '1 day') AS gs(day_value)
    LEFT JOIN public.rooms r ON r.id = sch.room_id
    WHERE (
      EXTRACT(ISODOW FROM gs.day_value)::INT = sch.day_of_week
      OR EXTRACT(DOW FROM gs.day_value)::INT = sch.day_of_week
    )
      AND (sch.effective_from IS NULL OR gs.day_value::DATE >= sch.effective_from)
      AND (sch.effective_to IS NULL OR gs.day_value::DATE <= sch.effective_to)
      AND NOT EXISTS (
        SELECT 1 FROM session_rows sr 
        WHERE sr.group_id = g.id AND sr.session_date = gs.day_value::DATE
      )
  )
  SELECT * FROM session_rows
  UNION ALL
  SELECT * FROM schedule_occurrences
  ORDER BY session_date ASC, start_time ASC;
END;
$$;

-- 3. Parent-facing get_parent_child_schedule RPC
CREATE OR REPLACE FUNCTION public.get_parent_child_schedule(
  p_student_id UUID,
  p_from_date DATE DEFAULT CURRENT_DATE,
  p_to_date DATE DEFAULT (CURRENT_DATE + INTERVAL '30 days')::DATE
)
RETURNS TABLE (
  source_type TEXT,
  enrollment_id UUID,
  access_status TEXT,
  payment_status TEXT,
  group_id UUID,
  group_name TEXT,
  subject_id UUID,
  subject_name TEXT,
  branch_id UUID,
  branch_name TEXT,
  schedule_id UUID,
  class_session_id UUID,
  session_date DATE,
  day_of_week INT,
  start_time TIME,
  end_time TIME,
  scheduled_start_at TIMESTAMPTZ,
  scheduled_end_at TIMESTAMPTZ,
  status TEXT,
  room_id UUID,
  room_code TEXT,
  room_name TEXT,
  location TEXT,
  teacher_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID;
BEGIN
  SELECT s.id INTO v_student_id
  FROM public.students s
  WHERE s.id = p_student_id OR s.profile_id = p_student_id
  LIMIT 1;

  IF v_student_id IS NULL THEN
    v_student_id := p_student_id;
  END IF;

  IF NOT (
    public.parent_can_access_student(v_student_id)
    OR public.current_parent_has_student(v_student_id)
    OR public.is_admin_or_super()
    OR public.has_permission('schedules.view')
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view child schedule' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.get_student_schedule(v_student_id, p_from_date, p_to_date);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_schedule(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_parent_child_schedule(UUID, DATE, DATE) TO authenticated;
