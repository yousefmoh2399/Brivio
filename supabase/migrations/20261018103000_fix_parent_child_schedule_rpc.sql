-- Migration: 20261018103000_fix_parent_child_schedule_rpc.sql
-- Description: Fix operator does not exist (date || text) and column g.teacher_id in parent child schedule RPCs.

-- 1. Ensure groups has teacher_id column
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_groups_teacher_id ON public.groups(teacher_id);

-- 2. Clean recreate schedule functions
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
  v_student_id UUID := p_student_id;
BEGIN
  -- Resolve student ID (handles both students.id and profiles.id)
  SELECT s.id INTO v_student_id
  FROM public.students s
  WHERE s.id = p_student_id OR s.profile_id = p_student_id
  LIMIT 1;

  IF v_student_id IS NULL THEN
    v_student_id := p_student_id;
  END IF;

  RETURN QUERY
  WITH active_enrollments AS (
    SELECT 
      e.id AS enrollment_id, 
      e.student_id, 
      e.group_id, 
      COALESCE(e.access_status::TEXT, 'active') AS access_status, 
      COALESCE(e.payment_status::TEXT, 'paid') AS payment_status
    FROM public.enrollments e
    WHERE (e.student_id = v_student_id OR e.student_id IN (SELECT id FROM public.students WHERE id = v_student_id OR profile_id = v_student_id))
      AND (LOWER(COALESCE(e.status::TEXT, 'active')) NOT IN ('cancelled', 'dropped', 'suspended'))
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
      COALESCE(sub.name, 'حصة دراسية')::TEXT AS subject_name,
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
      COALESCE(
        (SELECT p.full_name FROM public.profiles p WHERE p.id IN (SELECT profile_id FROM public.teachers WHERE id = cs.teacher_id) LIMIT 1),
        (SELECT p.full_name FROM public.group_teachers gt JOIN public.teachers t ON t.id = gt.teacher_id JOIN public.profiles p ON p.id = t.profile_id WHERE gt.group_id = g.id AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE) ORDER BY gt.is_primary DESC NULLS LAST LIMIT 1),
        (SELECT p.full_name FROM public.teachers t JOIN public.profiles p ON p.id = t.profile_id WHERE t.id = g.teacher_id LIMIT 1),
        'معلم المادة'
      )::TEXT AS teacher_name
    FROM active_enrollments ae
    JOIN public.groups g ON g.id = ae.group_id
    LEFT JOIN public.subjects sub ON sub.id = g.subject_id
    LEFT JOIN public.branches b ON b.id = g.branch_id
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
      COALESCE(sub.name, 'حصة دراسية')::TEXT AS subject_name,
      g.branch_id,
      COALESCE(b.name, 'الفرع الرئيسي')::TEXT AS branch_name,
      sch.id AS schedule_id,
      NULL::UUID AS class_session_id,
      gs.day_value::DATE AS session_date,
      sch.day_of_week,
      sch.start_time,
      sch.end_time,
      (gs.day_value::DATE + sch.start_time)::TIMESTAMPTZ AS scheduled_start_at,
      (gs.day_value::DATE + sch.end_time)::TIMESTAMPTZ AS scheduled_end_at,
      COALESCE(sch.status, 'active')::TEXT AS status,
      sch.room_id,
      r.code AS room_code,
      r.name AS room_name,
      COALESCE(sch.location, r.name, 'القاعة الرئيسية')::TEXT AS location,
      COALESCE(
        (SELECT p.full_name FROM public.group_teachers gt JOIN public.teachers t ON t.id = gt.teacher_id JOIN public.profiles p ON p.id = t.profile_id WHERE gt.group_id = g.id AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE) ORDER BY gt.is_primary DESC NULLS LAST LIMIT 1),
        (SELECT p.full_name FROM public.teachers t JOIN public.profiles p ON p.id = t.profile_id WHERE t.id = g.teacher_id LIMIT 1),
        'معلم المادة'
      )::TEXT AS teacher_name
    FROM active_enrollments ae
    JOIN public.groups g ON g.id = ae.group_id
    LEFT JOIN public.subjects sub ON sub.id = g.subject_id
    LEFT JOIN public.branches b ON b.id = g.branch_id
    JOIN public.schedules sch ON sch.group_id = g.id AND (sch.status = 'active' OR sch.status IS NULL)
    CROSS JOIN generate_series(p_from_date, p_to_date, INTERVAL '1 day') AS gs(day_value)
    LEFT JOIN public.rooms r ON r.id = sch.room_id
    WHERE (
      EXTRACT(ISODOW FROM gs.day_value)::INT = sch.day_of_week
      OR EXTRACT(DOW FROM gs.day_value)::INT = sch.day_of_week
      OR (sch.day_of_week = 6 AND EXTRACT(ISODOW FROM gs.day_value)::INT = 6)
      OR (sch.day_of_week = 7 AND EXTRACT(ISODOW FROM gs.day_value)::INT = 7)
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
  v_student_id UUID := p_student_id;
BEGIN
  -- Resolve student ID
  SELECT s.id INTO v_student_id
  FROM public.students s
  WHERE s.id = p_student_id OR s.profile_id = p_student_id
  LIMIT 1;

  IF v_student_id IS NULL THEN
    v_student_id := p_student_id;
  END IF;

  -- Security check: allow parent, student themselves, or admin/staff
  IF NOT (
    public.is_admin_or_super()
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    OR public.has_permission('schedules.view')
    OR public.parent_can_access_student(v_student_id)
    OR public.current_parent_has_student(v_student_id)
    OR EXISTS (SELECT 1 FROM public.students s WHERE (s.id = v_student_id OR s.profile_id = v_student_id) AND s.profile_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.parent_students ps
      WHERE (ps.student_id = v_student_id OR ps.student_id IN (SELECT id FROM public.students WHERE profile_id = v_student_id))
        AND (ps.parent_id = public.current_parent_id() OR ps.parent_id IN (SELECT id FROM public.parents WHERE profile_id = auth.uid()))
    )
    OR EXISTS (
      SELECT 1 FROM public.parents p WHERE p.profile_id = auth.uid()
    )
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

NOTIFY pgrst, 'reload schema';
