-- Migration: 20261018100000_fix_groups_teacher_id_and_teacher_finance.sql
-- Description: Fix missing `groups.teacher_id` column and robust teacher finance overview function.

-- 1. Ensure `teacher_id` column exists on `public.groups`
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_groups_teacher_id ON public.groups(teacher_id);

-- 2. Backfill existing teacher assignments into `public.groups.teacher_id` from canonical `public.group_teachers`
UPDATE public.groups g
SET teacher_id = gt.teacher_id
FROM public.group_teachers gt
WHERE gt.group_id = g.id
  AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
  AND g.teacher_id IS NULL;

-- 3. Automatic Synchronization Trigger between groups.teacher_id and group_teachers
CREATE OR REPLACE FUNCTION public.sync_group_teacher_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.teacher_id IS NOT NULL THEN
    INSERT INTO public.group_teachers (group_id, teacher_id, role, is_primary, effective_from)
    VALUES (NEW.id, NEW.teacher_id, 'primary', true, CURRENT_DATE)
    ON CONFLICT (group_id, teacher_id, effective_from) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_group_teacher_assignment ON public.groups;
CREATE TRIGGER trg_sync_group_teacher_assignment
AFTER INSERT OR UPDATE OF teacher_id ON public.groups
FOR EACH ROW
WHEN (NEW.teacher_id IS NOT NULL)
EXECUTE FUNCTION public.sync_group_teacher_assignment();

-- 4. Robust get_teacher_financial_overview function
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
  v_teacher_id UUID := p_teacher_id;
BEGIN
  -- Resolve teacher id (supports teachers.id or profiles.id / auth.uid())
  IF v_teacher_id IS NOT NULL THEN
    SELECT t.id INTO v_teacher_id
    FROM public.teachers t
    WHERE t.id = v_teacher_id OR t.profile_id = v_teacher_id
    LIMIT 1;
  ELSE
    v_teacher_id := public.current_teacher_id();
  END IF;

  IF v_teacher_id IS NULL THEN
    -- If still null, try finding teacher for current auth user
    SELECT t.id INTO v_teacher_id
    FROM public.teachers t
    WHERE t.profile_id = auth.uid()
    LIMIT 1;
  END IF;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Teacher profile is required or not found for this user' USING ERRCODE = '42501';
  END IF;

  -- Authorization check
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('payments.view')
    OR public.has_permission('payments.collect')
    OR v_teacher_id = public.current_teacher_id()
    OR EXISTS (SELECT 1 FROM public.teachers t WHERE t.id = v_teacher_id AND t.profile_id = auth.uid())
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

GRANT EXECUTE ON FUNCTION public.get_teacher_financial_overview(UUID) TO authenticated;

-- 5. Robust get_teacher_group_finance_roster function
DROP FUNCTION IF EXISTS public.get_teacher_group_finance_roster(UUID);

CREATE OR REPLACE FUNCTION public.get_teacher_group_finance_roster(p_group_id UUID)
RETURNS TABLE (
  enrollment_id UUID,
  student_id UUID,
  student_name TEXT,
  student_code TEXT,
  invoice_id UUID,
  invoice_number TEXT,
  original_price_minor BIGINT,
  discount_minor BIGINT,
  final_price_minor BIGINT,
  paid_amount_minor BIGINT,
  remaining_amount_minor BIGINT,
  currency TEXT,
  access_status TEXT,
  payment_status TEXT,
  payment_exempt BOOLEAN,
  pending_adjustment_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('payments.view')
    OR public.has_permission('payments.collect')
    OR public.current_teacher_assigned_to_group(p_group_id)
    OR EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = p_group_id
        AND (g.teacher_id = public.current_teacher_id() OR g.teacher_id IN (SELECT id FROM public.teachers WHERE profile_id = auth.uid()))
    )
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view group finance roster' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    e.id AS enrollment_id,
    st.id AS student_id,
    p.full_name AS student_name,
    st.student_code,
    inv.id AS invoice_id,
    inv.invoice_number,
    COALESCE(e.original_price_minor, inv.subtotal_minor, 0)::BIGINT AS original_price_minor,
    COALESCE(e.discount_minor, inv.discount_minor, 0)::BIGINT AS discount_minor,
    COALESCE(e.final_price_minor, inv.total_minor, 0)::BIGINT AS final_price_minor,
    COALESCE(inv.amount_paid_minor, 0)::BIGINT AS paid_amount_minor,
    GREATEST(COALESCE(e.final_price_minor, inv.total_minor, 0) - COALESCE(inv.amount_paid_minor, 0), 0)::BIGINT AS remaining_amount_minor,
    COALESCE(e.currency, inv.currency, 'EGP') AS currency,
    COALESCE(e.access_status, 'active') AS access_status,
    COALESCE(e.payment_status, 'paid') AS payment_status,
    COALESCE(e.payment_exempt, false) AS payment_exempt,
    COALESCE((
      SELECT COUNT(*)
      FROM public.payment_adjustment_requests par
      WHERE par.enrollment_id = e.id
        AND par.status = 'pending'
    ), 0)::BIGINT AS pending_adjustment_count
  FROM public.enrollments e
  JOIN public.students st ON st.id = e.student_id
  JOIN public.profiles p ON p.id = st.profile_id
  LEFT JOIN public.invoices inv ON inv.id = e.activation_invoice_id
  WHERE e.group_id = p_group_id
    AND e.status = 'active'
  ORDER BY p.full_name;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_group_finance_roster(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
