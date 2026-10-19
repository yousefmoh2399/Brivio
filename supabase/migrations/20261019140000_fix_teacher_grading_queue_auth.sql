-- Migration: 20261019140000_fix_teacher_grading_queue_auth.sql
-- Description: Robust teacher grading queue authorization and multi-identifier resolution (teachers.id vs profiles.id)

DROP FUNCTION IF EXISTS public.get_teacher_grading_queue(UUID);

CREATE OR REPLACE FUNCTION public.get_teacher_grading_queue(p_teacher_id UUID DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  assessment_id UUID,
  student_id UUID,
  status TEXT,
  score NUMERIC,
  submitted_at TIMESTAMPTZ,
  max_score NUMERIC,
  assessment_title TEXT,
  group_id UUID,
  student_full_name TEXT,
  student_email TEXT,
  submission_text TEXT,
  attachment_url TEXT,
  assessment_type TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID := p_teacher_id;
  v_profile_id UUID := auth.uid();
BEGIN
  -- 1. Resolve canonical teacher id (handles teachers.id or profiles.id)
  IF v_teacher_id IS NOT NULL THEN
    SELECT t.id INTO v_teacher_id
    FROM public.teachers t
    WHERE t.id = v_teacher_id OR t.profile_id = v_teacher_id
    LIMIT 1;
  END IF;

  -- 2. Fallback to current authenticated teacher if not resolved
  IF v_teacher_id IS NULL THEN
    v_teacher_id := public.current_teacher_id();
  END IF;

  IF v_teacher_id IS NULL AND v_profile_id IS NOT NULL THEN
    SELECT t.id INTO v_teacher_id
    FROM public.teachers t
    WHERE t.profile_id = v_profile_id
    LIMIT 1;
  END IF;

  -- 3. Authorization check
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('homework.grade')
    OR (v_teacher_id IS NOT NULL AND v_teacher_id = public.current_teacher_id())
    OR (v_profile_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.teachers t WHERE (t.id = v_teacher_id OR t.profile_id = v_teacher_id) AND t.profile_id = v_profile_id
    ))
    OR public.current_user_role() = 'teacher'
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view grading queue' USING ERRCODE = '42501';
  END IF;

  -- 4. Return submissions for the teacher's groups, homework, and exams
  RETURN QUERY
  SELECT
    hs.id,
    hs.homework_id AS assessment_id,
    hs.student_id,
    COALESCE(hs.status, 'submitted')::TEXT AS status,
    hs.score,
    hs.submitted_at,
    h.max_score,
    COALESCE(h.title, 'Homework')::TEXT AS assessment_title,
    h.group_id,
    COALESCE(p.full_name, 'Student')::TEXT AS student_full_name,
    COALESCE(p.email, '')::TEXT AS student_email,
    hs.submission_text,
    hs.attachment_url,
    'homework'::TEXT AS assessment_type
  FROM public.homework_submissions hs
  JOIN public.homework h ON h.id = hs.homework_id
  JOIN public.students s ON s.id = hs.student_id
  LEFT JOIN public.profiles p ON p.id = s.profile_id
  WHERE (
    -- Group assigned to teacher via group_teachers
    h.group_id IN (
      SELECT gt.group_id
      FROM public.group_teachers gt
      WHERE gt.teacher_id = v_teacher_id
        AND gt.effective_from <= CURRENT_DATE
        AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
    )
    -- OR Group has teacher_id = v_teacher_id
    OR h.group_id IN (
      SELECT g.id
      FROM public.groups g
      WHERE g.teacher_id = v_teacher_id
    )
    -- OR homework directly assigned by teacher profile/teacher_id
    OR h.assigned_by = v_profile_id
    OR h.assigned_by = v_teacher_id
  )
  UNION ALL
  SELECT
    ea.id,
    ea.exam_id AS assessment_id,
    ea.student_id,
    COALESCE(ea.status, 'submitted')::TEXT AS status,
    ea.score,
    ea.submitted_at,
    ea.max_score,
    COALESCE(e.title, 'Exam')::TEXT AS assessment_title,
    e.group_id,
    COALESCE(p.full_name, 'Student')::TEXT AS student_full_name,
    COALESCE(p.email, '')::TEXT AS student_email,
    NULL::TEXT AS submission_text,
    NULL::TEXT AS attachment_url,
    'exam'::TEXT AS assessment_type
  FROM public.exam_attempts ea
  JOIN public.exams e ON e.id = ea.exam_id
  JOIN public.students s ON s.id = ea.student_id
  LEFT JOIN public.profiles p ON p.id = s.profile_id
  WHERE ea.status IN ('submitted', 'graded') 
  AND (
    -- Group assigned to teacher via group_teachers
    e.group_id IN (
      SELECT gt.group_id
      FROM public.group_teachers gt
      WHERE gt.teacher_id = v_teacher_id
        AND gt.effective_from <= CURRENT_DATE
        AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
    )
    -- OR Group has teacher_id = v_teacher_id
    OR e.group_id IN (
      SELECT g.id
      FROM public.groups g
      WHERE g.teacher_id = v_teacher_id
    )
    -- OR exam created by teacher profile/teacher_id
    OR e.created_by = v_profile_id
    OR e.created_by = v_teacher_id
  )
  ORDER BY submitted_at DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_teacher_grading_queue(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_grading_queue(UUID) TO authenticated;
