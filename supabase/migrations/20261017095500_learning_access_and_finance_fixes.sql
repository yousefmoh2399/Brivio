-- Migration: 20261017095500_learning_access_and_finance_fixes.sql
-- Description: Fix get_accessible_student_lessons to support units without semesters, 
-- relax enrollment_has_learning_access for active students,
-- fix get_teacher_financial_overview to support groups.teacher_id,
-- and add center_id to receipts & payment_transactions.

-- 1. Ensure center_id exists on receipts and payment_transactions
ALTER TABLE public.receipts
  ADD COLUMN IF NOT EXISTS center_id UUID REFERENCES public.educational_centers(id) ON DELETE SET NULL;

ALTER TABLE public.payment_transactions
  ADD COLUMN IF NOT EXISTS center_id UUID REFERENCES public.educational_centers(id) ON DELETE SET NULL;

-- 2. Relax enrollment_has_learning_access
CREATE OR REPLACE FUNCTION public.enrollment_has_learning_access(p_enrollment_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.enrollments e
    WHERE e.id = p_enrollment_id
      AND e.status = 'active'
      AND (e.access_status IS NULL OR e.access_status != 'blocked')
  );
$$;

-- 3. Fix get_current_student_lessons
DROP FUNCTION IF EXISTS public.get_current_student_lessons();
CREATE OR REPLACE FUNCTION public.get_current_student_lessons()
RETURNS TABLE (
  lesson_id UUID,
  lesson_title TEXT,
  group_id UUID,
  subject_name TEXT,
  unit_name TEXT,
  progress_percentage NUMERIC,
  estimated_minutes INT,
  last_page INT,
  total_pages INT,
  time_spent_seconds INT,
  has_pdf BOOLEAN,
  has_code_playground BOOLEAN,
  pdf_bucket TEXT,
  pdf_object_path TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (g.id, l.id)
    l.id AS lesson_id,
    COALESCE(l.title, 'Untitled lesson')::TEXT AS lesson_title,
    g.id AS group_id,
    COALESCE(s.name, 'Assigned subject')::TEXT AS subject_name,
    COALESCE(u.name, 'Unit')::TEXT AS unit_name,
    COALESCE(lp.progress_percentage, 0)::NUMERIC AS progress_percentage,
    COALESCE(l.estimated_duration_minutes, 0)::INT AS estimated_minutes,
    GREATEST(1, COALESCE(CASE WHEN COALESCE(lp.last_position, '') ~ '^[0-9]+$' THEN lp.last_position::INT ELSE NULL END, 1))::INT AS last_page,
    GREATEST(1, COALESCE(NULLIF((lr.metadata->>'page_count'), '')::INT, 1))::INT AS total_pages,
    COALESCE(lp.time_spent_seconds, 0)::INT AS time_spent_seconds,
    (lr.id IS NOT NULL)::BOOLEAN AS has_pdf,
    (l.lesson_type::TEXT = 'programming')::BOOLEAN AS has_code_playground,
    lr.bucket::TEXT AS pdf_bucket,
    lr.object_path::TEXT AS pdf_object_path
  FROM public.enrollments e
  JOIN public.groups g ON g.id = e.group_id
  JOIN public.units u ON u.subject_id = g.subject_id
  LEFT JOIN public.semesters sem ON sem.id = u.semester_id
  JOIN public.lessons l ON l.unit_id = u.id
  LEFT JOIN public.subjects s ON s.id = g.subject_id
  LEFT JOIN public.lesson_progress lp ON lp.lesson_id = l.id AND lp.student_id = v_student_id
  LEFT JOIN public.lesson_resources lr ON lr.lesson_id = l.id AND lr.resource_type = 'pdf'
  WHERE e.student_id = v_student_id
    AND public.enrollment_has_learning_access(e.id)
    AND g.status = 'active'
    AND u.status = 'active'
    AND l.status = 'published'
  ORDER BY g.id, l.id, COALESCE(sem.order_number, 0), u.order_number, l.order_number, lr.order_number;
END;
$$;

-- 4. Fix get_accessible_student_lessons
DROP FUNCTION IF EXISTS public.get_accessible_student_lessons(UUID);
CREATE OR REPLACE FUNCTION public.get_accessible_student_lessons(p_student_id UUID)
RETURNS TABLE (
  lesson_id UUID,
  lesson_title TEXT,
  group_id UUID,
  subject_name TEXT,
  unit_name TEXT,
  progress_percentage NUMERIC,
  estimated_minutes INT,
  last_page INT,
  total_pages INT,
  time_spent_seconds INT,
  has_pdf BOOLEAN,
  has_code_playground BOOLEAN,
  pdf_bucket TEXT,
  pdf_object_path TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_student_id IS NULL THEN
    RAISE EXCEPTION 'Student id is required' USING ERRCODE = '22023';
  END IF;

  IF NOT (
    p_student_id = public.current_student_id()
    OR public.current_parent_has_student(p_student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view student lessons' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (g.id, l.id)
    l.id AS lesson_id,
    COALESCE(l.title, 'Untitled lesson')::TEXT AS lesson_title,
    g.id AS group_id,
    COALESCE(s.name, 'Assigned subject')::TEXT AS subject_name,
    COALESCE(u.name, 'Unit')::TEXT AS unit_name,
    COALESCE(lp.progress_percentage, 0)::NUMERIC AS progress_percentage,
    COALESCE(l.estimated_duration_minutes, 0)::INT AS estimated_minutes,
    GREATEST(1, COALESCE(CASE WHEN COALESCE(lp.last_position, '') ~ '^[0-9]+$' THEN lp.last_position::INT ELSE NULL END, 1))::INT AS last_page,
    GREATEST(1, COALESCE(NULLIF((lr.metadata->>'page_count'), '')::INT, 1))::INT AS total_pages,
    COALESCE(lp.time_spent_seconds, 0)::INT AS time_spent_seconds,
    (lr.id IS NOT NULL)::BOOLEAN AS has_pdf,
    (l.lesson_type::TEXT = 'programming')::BOOLEAN AS has_code_playground,
    lr.bucket::TEXT AS pdf_bucket,
    lr.object_path::TEXT AS pdf_object_path
  FROM public.enrollments e
  JOIN public.groups g ON g.id = e.group_id
  JOIN public.units u ON u.subject_id = g.subject_id
  LEFT JOIN public.semesters sem ON sem.id = u.semester_id
  JOIN public.lessons l ON l.unit_id = u.id
  LEFT JOIN public.subjects s ON s.id = g.subject_id
  LEFT JOIN public.lesson_progress lp ON lp.lesson_id = l.id AND lp.student_id = p_student_id
  LEFT JOIN public.lesson_resources lr ON lr.lesson_id = l.id AND lr.resource_type = 'pdf'
  WHERE e.student_id = p_student_id
    AND public.enrollment_has_learning_access(e.id)
    AND g.status = 'active'
    AND u.status = 'active'
    AND l.status = 'published'
  ORDER BY g.id, l.id, COALESCE(sem.order_number, 0), u.order_number, l.order_number, lr.order_number;
END;
$$;

-- 5. Fix get_teacher_financial_overview
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL;

DROP FUNCTION IF EXISTS public.get_teacher_financial_overview(UUID);
CREATE OR REPLACE FUNCTION public.get_teacher_financial_overview(p_teacher_id UUID DEFAULT NULL)
RETURNS TABLE (
  group_id UUID,
  group_name TEXT,
  group_code TEXT,
  subject_name TEXT,
  total_students BIGINT,
  paid_students BIGINT,
  unpaid_students BIGINT,
  exempt_students BIGINT,
  total_amount_minor BIGINT,
  paid_amount_minor BIGINT,
  remaining_amount_minor BIGINT,
  currency TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID := COALESCE(p_teacher_id, public.current_teacher_id());
BEGIN
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Teacher profile is required' USING ERRCODE = '42501';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('payments.view')
    OR public.has_permission('payments.collect')
    OR v_teacher_id = public.current_teacher_id()
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view teacher finance' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH assigned_groups AS (
    SELECT DISTINCT g.id, g.name, g.code, g.subject_id
    FROM public.groups g
    WHERE g.teacher_id = v_teacher_id
       OR EXISTS (
            SELECT 1
            FROM public.group_teachers gt
            WHERE gt.group_id = g.id
              AND gt.teacher_id = v_teacher_id
              AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
       )
  ),
  finance_rows AS (
    SELECT
      ag.id AS group_id,
      ag.name AS group_name,
      ag.code AS group_code,
      s.name AS subject_name,
      e.id AS enrollment_id,
      COALESCE(e.currency, inv.currency, 'EGP') AS currency,
      COALESCE(e.final_price_minor, inv.total_minor, 0) AS final_price_minor,
      COALESCE(inv.amount_paid_minor, 0) AS paid_minor,
      e.payment_status,
      e.payment_exempt
    FROM assigned_groups ag
    LEFT JOIN public.subjects s ON s.id = ag.subject_id
    LEFT JOIN public.enrollments e ON e.group_id = ag.id AND e.status = 'active'
    LEFT JOIN public.invoices inv ON inv.id = e.activation_invoice_id
  )
  SELECT
    fr.group_id,
    fr.group_name,
    fr.group_code,
    fr.subject_name,
    COUNT(fr.enrollment_id)::BIGINT AS total_students,
    COUNT(fr.enrollment_id) FILTER (
      WHERE fr.payment_status IN ('paid', 'exempt') OR fr.payment_exempt = true
    )::BIGINT AS paid_students,
    COUNT(fr.enrollment_id) FILTER (
      WHERE COALESCE(fr.final_price_minor, 0) > COALESCE(fr.paid_minor, 0)
        AND COALESCE(fr.payment_exempt, false) = false
    )::BIGINT AS unpaid_students,
    COUNT(fr.enrollment_id) FILTER (
      WHERE fr.payment_status = 'exempt' OR fr.payment_exempt = true
    )::BIGINT AS exempt_students,
    COALESCE(SUM(fr.final_price_minor), 0)::BIGINT AS total_amount_minor,
    COALESCE(SUM(fr.paid_minor), 0)::BIGINT AS paid_amount_minor,
    COALESCE(SUM(GREATEST(fr.final_price_minor - fr.paid_minor, 0)), 0)::BIGINT AS remaining_amount_minor,
    COALESCE(MAX(fr.currency), 'EGP') AS currency
  FROM finance_rows fr
  GROUP BY fr.group_id, fr.group_name, fr.group_code, fr.subject_name;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_current_student_lessons() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_accessible_student_lessons(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_teacher_financial_overview(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enrollment_has_learning_access(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
