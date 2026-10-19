-- UNIFIED FIX SCRIPT
-- Please run this ENTIRE script in your Supabase SQL Editor

-- 1. Fix is_teacher_of_group helper
CREATE OR REPLACE FUNCTION public.is_teacher_of_group(teacher_user_id UUID, target_group_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    t_id UUID;
    is_assigned BOOLEAN := false;
BEGIN
    t_id := public.get_teacher_id(teacher_user_id);
    IF t_id IS NULL THEN RETURN false; END IF;
    SELECT EXISTS (
        SELECT 1 FROM public.group_teachers
        WHERE group_id = target_group_id 
          AND teacher_id = t_id
          AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)
    ) INTO is_assigned;
    RETURN is_assigned;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. Drop the old Groups and Schedules RLS policies
DROP POLICY IF EXISTS "Groups viewable by enrolled students, assigned teachers, staff, admins" ON public.groups;
DROP POLICY IF EXISTS "Schedules viewable by group participants, staff, admins" ON public.schedules;

-- 3. Recreate the Schedules RLS Policy
CREATE POLICY "Schedules viewable by group participants, staff, admins" ON public.schedules FOR SELECT TO authenticated USING (
    public.is_student_enrolled_in_group(auth.uid(), group_id)
    OR public.is_teacher_of_group(auth.uid(), group_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
);

-- 4. Recreate the Finance Overview Function
DROP FUNCTION IF EXISTS public.get_teacher_financial_overview(uuid);

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
    FROM public.group_teachers gt
    JOIN public.groups g ON g.id = gt.group_id
    WHERE gt.teacher_id = v_teacher_id
      AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
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
  GROUP BY fr.group_id, fr.group_name, fr.group_code, fr.subject_name
  ORDER BY fr.group_name;
END;
$$;

-- 5. Recreate Roster Function
DROP FUNCTION IF EXISTS public.get_teacher_group_finance_roster(uuid);

CREATE OR REPLACE FUNCTION public.get_teacher_group_finance_roster(p_group_id UUID)
RETURNS TABLE (
  student_id UUID,
  student_name TEXT,
  parent_phone TEXT,
  enrollment_id UUID,
  payment_status TEXT,
  payment_exempt BOOLEAN,
  final_price_minor BIGINT,
  paid_minor BIGINT,
  remaining_minor BIGINT,
  currency TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.has_permission('payments.view') AND NOT EXISTS (
      SELECT 1 FROM public.group_teachers gt
      WHERE gt.group_id = p_group_id
        AND gt.teacher_id = public.current_teacher_id()
    ) THEN
      RAISE EXCEPTION 'Unauthorized to view group roster' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT 
      st.id AS student_id,
      pr.full_name AS student_name,
      par_pr.phone_number AS parent_phone,
      e.id AS enrollment_id,
      e.payment_status,
      e.payment_exempt,
      COALESCE(e.final_price_minor, inv.total_minor, 0)::BIGINT AS final_price_minor,
      COALESCE(inv.amount_paid_minor, 0)::BIGINT AS paid_minor,
      GREATEST(COALESCE(e.final_price_minor, inv.total_minor, 0) - COALESCE(inv.amount_paid_minor, 0), 0)::BIGINT AS remaining_minor,
      COALESCE(e.currency, inv.currency, 'EGP') AS currency
    FROM public.enrollments e
    JOIN public.students st ON st.id = e.student_id
    JOIN public.profiles pr ON pr.id = st.profile_id
    LEFT JOIN public.parent_students ps ON ps.student_id = st.id
    LEFT JOIN public.parents par ON par.id = ps.parent_id
    LEFT JOIN public.profiles par_pr ON par_pr.id = par.profile_id
    LEFT JOIN public.invoices inv ON inv.id = e.activation_invoice_id
    WHERE e.group_id = p_group_id
      AND e.status = 'active'
    ORDER BY pr.full_name;
END;
$$;-- Migration: 20261019150000_center_financial_cycle_and_reschedule.sql
-- Description: Comprehensive center financial collection cycle:
-- 1. Reschedule / modify invoice payment due date (with audit reason & instant notification)
-- 2. Automated & on-demand monthly billing cycle generator (issued 1st of every month / scheduled dues)
-- 3. Automatic invoice generation trigger on student group enrollments

-- ==============================================================================
-- 1. RESCHEDULE INVOICE DUE DATE RPC
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.reschedule_invoice_due_date(
  p_invoice_id UUID,
  p_new_due_at TIMESTAMPTZ,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inv RECORD;
  v_student_profile UUID;
  v_parent_profile UUID;
  v_formatted_date TEXT;
  v_new_status TEXT;
BEGIN
  -- Permission check: admin, super_admin, or staff with finance permission
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('invoices.manage')
    OR public.has_permission('payments.collect')
    OR public.current_user_role() IN ('admin', 'super_admin', 'staff')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to reschedule invoice due date' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_inv
  FROM public.invoices
  WHERE id = p_invoice_id
  FOR UPDATE;

  IF v_inv.id IS NULL THEN
    RAISE EXCEPTION 'Invoice not found: %', p_invoice_id USING ERRCODE = 'P0002';
  END IF;

  -- Determine if status should be restored from 'overdue' if new date is in the future
  v_new_status := v_inv.status;
  IF v_inv.status = 'overdue' AND p_new_due_at > NOW() THEN
    IF v_inv.amount_paid_minor > 0 THEN
      v_new_status := 'partially_paid';
    ELSE
      v_new_status := 'issued';
    END IF;
  END IF;

  UPDATE public.invoices
  SET due_at = p_new_due_at,
      status = v_new_status,
      updated_at = NOW()
  WHERE id = p_invoice_id;

  -- Format date for notifications (YYYY-MM-DD)
  v_formatted_date := to_char(p_new_due_at AT TIME ZONE 'UTC', 'YYYY-MM-DD');

  -- Get student profile
  SELECT s.profile_id INTO v_student_profile
  FROM public.students s
  WHERE s.id = v_inv.student_id;

  -- Notify student
  IF v_student_profile IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (user_id, notification_type, title, body, data)
      VALUES (
        v_student_profile,
        'invoice_rescheduled',
        'تعديل موعد سداد الفاتورة 📅',
        'تم تعديل موعد سداد فاتورة رقم ' || COALESCE(v_inv.invoice_number, '') || ' حتى ' || v_formatted_date || COALESCE(' (' || p_reason || ')', '') || '.',
        jsonb_build_object(
          'invoice_id', p_invoice_id,
          'invoice_number', v_inv.invoice_number,
          'new_due_at', p_new_due_at,
          'reason', p_reason
        )
      );
    EXCEPTION WHEN undefined_table OR undefined_column THEN
      NULL;
    END;
  END IF;

  -- Notify linked parents
  FOR v_parent_profile IN
    SELECT p.profile_id
    FROM public.parent_students ps
    JOIN public.parents p ON p.id = ps.parent_id
    WHERE ps.student_id = v_inv.student_id
  LOOP
    BEGIN
      INSERT INTO public.notifications (user_id, notification_type, title, body, data)
      VALUES (
        v_parent_profile,
        'invoice_rescheduled',
        'تعديل موعد استحقاق الفاتورة 📅',
        'تم تمديد/تعديل موعد سداد الفاتورة رقم ' || COALESCE(v_inv.invoice_number, '') || ' حتى تاريخ ' || v_formatted_date || COALESCE(' (' || p_reason || ')', '') || '.',
        jsonb_build_object(
          'invoice_id', p_invoice_id,
          'invoice_number', v_inv.invoice_number,
          'new_due_at', p_new_due_at,
          'student_id', v_inv.student_id,
          'reason', p_reason
        )
      );
    EXCEPTION WHEN undefined_table OR undefined_column THEN
      NULL;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'invoice_id', p_invoice_id,
    'new_due_at', p_new_due_at,
    'status', v_new_status,
    'message', 'Invoice due date updated successfully'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reschedule_invoice_due_date(UUID, TIMESTAMPTZ, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reschedule_invoice_due_date(UUID, TIMESTAMPTZ, TEXT) TO authenticated, service_role;

-- ==============================================================================
-- 2. GENERATE MONTHLY BILLING CYCLE RPC (توليد مطالبات ومصروفات أول الشهر)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.generate_monthly_billing_cycle(
  p_center_id UUID DEFAULT NULL,
  p_billing_month DATE DEFAULT CURRENT_DATE,
  p_due_days INT DEFAULT 7
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_center_id UUID := p_center_id;
  v_start_of_month DATE;
  v_end_of_month DATE;
  v_due_date TIMESTAMPTZ;
  v_created_count INT := 0;
  v_skipped_count INT := 0;
  v_total_amount_minor BIGINT := 0;
  v_rec RECORD;
  v_invoice_id UUID;
  v_month_label TEXT;
  v_student_profile UUID;
  v_parent_profile UUID;
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('invoices.manage')
    OR public.has_permission('payments.collect')
    OR public.current_user_role() IN ('admin', 'super_admin', 'staff')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to run billing cycle' USING ERRCODE = '42501';
  END IF;

  IF v_center_id IS NULL THEN
    v_center_id := public.current_user_center_id();
  END IF;

  v_start_of_month := date_trunc('month', p_billing_month)::DATE;
  v_end_of_month := (date_trunc('month', p_billing_month) + INTERVAL '1 month - 1 day')::DATE;
  v_due_date := (v_start_of_month + (p_due_days || ' days')::INTERVAL)::TIMESTAMPTZ;
  v_month_label := to_char(v_start_of_month, 'MM/YYYY');

  -- Loop over active enrollments with a fee
  FOR v_rec IN
    SELECT 
      e.id AS enrollment_id,
      e.student_id,
      e.group_id,
      e.base_price_minor,
      e.discount_minor,
      COALESCE(NULLIF(e.final_price_minor, 0), GREATEST(0, e.base_price_minor - e.discount_minor)) AS final_price_minor,
      g.name AS group_name,
      s.student_code,
      p.full_name AS student_name,
      p.center_id AS profile_center_id
    FROM public.enrollments e
    JOIN public.groups g ON g.id = e.group_id
    JOIN public.students s ON s.id = e.student_id
    LEFT JOIN public.profiles p ON p.id = s.profile_id
    WHERE e.status = 'active'
      AND g.status = 'active'
      AND COALESCE(e.payment_exempt, false) = false
      AND COALESCE(NULLIF(e.final_price_minor, 0), e.base_price_minor) > 0
      AND (
        v_center_id IS NULL 
        OR g.branch_id IN (SELECT id FROM public.branches WHERE center_id = v_center_id)
        OR p.center_id = v_center_id
      )
  LOOP
    -- Check if an invoice was already issued for this enrollment in the specified billing month
    IF EXISTS (
      SELECT 1 
      FROM public.invoices inv
      WHERE inv.enrollment_id = v_rec.enrollment_id
        AND date_trunc('month', inv.issued_at) = v_start_of_month
        AND inv.status <> 'cancelled'
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    -- Create Invoice
    INSERT INTO public.invoices (
      student_id,
      enrollment_id,
      group_id,
      currency,
      subtotal_minor,
      discount_minor,
      total_minor,
      amount_paid_minor,
      status,
      issued_at,
      due_at
    )
    VALUES (
      v_rec.student_id,
      v_rec.enrollment_id,
      v_rec.group_id,
      'EGP',
      v_rec.base_price_minor,
      v_rec.discount_minor,
      v_rec.final_price_minor,
      0,
      'issued',
      v_start_of_month::TIMESTAMPTZ,
      v_due_date
    )
    RETURNING id INTO v_invoice_id;

    -- Create Line Item
    INSERT INTO public.invoice_items (
      invoice_id,
      description,
      quantity,
      unit_amount_minor,
      total_minor
    )
    VALUES (
      v_invoice_id,
      'مصروفات شهر ' || v_month_label || ' - مجموعة ' || v_rec.group_name,
      1,
      v_rec.final_price_minor,
      v_rec.final_price_minor
    );

    v_created_count := v_created_count + 1;
    v_total_amount_minor := v_total_amount_minor + v_rec.final_price_minor;

    -- Notify Student
    SELECT s.profile_id INTO v_student_profile
    FROM public.students s
    WHERE s.id = v_rec.student_id;

    IF v_student_profile IS NOT NULL THEN
      BEGIN
        INSERT INTO public.notifications (user_id, notification_type, title, body, data)
        VALUES (
          v_student_profile,
          'monthly_invoice_issued',
          'فاتورة شهرية جديدة 📑',
          'تم إصدار مطالبة رسوم شهر ' || v_month_label || ' لمجموعة (' || v_rec.group_name || ') بمبلغ ' || (v_rec.final_price_minor / 100)::TEXT || ' ج.م، موعد السداد حتى ' || to_char(v_due_date, 'YYYY-MM-DD') || '.',
          jsonb_build_object(
            'invoice_id', v_invoice_id,
            'group_id', v_rec.group_id,
            'student_id', v_rec.student_id,
            'amount_minor', v_rec.final_price_minor,
            'due_at', v_due_date
          )
        );
      EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
      END;
    END IF;

    -- Notify Parents
    FOR v_parent_profile IN
      SELECT p.profile_id
      FROM public.parent_students ps
      JOIN public.parents p ON p.id = ps.parent_id
      WHERE ps.student_id = v_rec.student_id
    LOOP
      BEGIN
        INSERT INTO public.notifications (user_id, notification_type, title, body, data)
        VALUES (
          v_parent_profile,
          'monthly_invoice_issued',
          'مطالبة دراسية لشهر ' || v_month_label || ' 📑',
          'تم إصدار مطالبة شهر ' || v_month_label || ' للطالب (' || COALESCE(v_rec.student_name, v_rec.student_code) || ') لمجموعة ' || v_rec.group_name || ' بمبلغ ' || (v_rec.final_price_minor / 100)::TEXT || ' ج.م، تستحق في ' || to_char(v_due_date, 'YYYY-MM-DD') || '.',
          jsonb_build_object(
            'invoice_id', v_invoice_id,
            'group_id', v_rec.group_id,
            'student_id', v_rec.student_id,
            'amount_minor', v_rec.final_price_minor,
            'due_at', v_due_date
          )
        );
      EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
      END;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'month', v_month_label,
    'invoices_created', v_created_count,
    'invoices_skipped', v_skipped_count,
    'total_amount_minor', v_total_amount_minor,
    'message', 'Monthly billing cycle executed successfully'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.generate_monthly_billing_cycle(UUID, DATE, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_monthly_billing_cycle(UUID, DATE, INT) TO authenticated, service_role;

-- ==============================================================================
-- 3. ENHANCE enroll_student_in_group TO GUARANTEE DUE DATE & INVOICE
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.enroll_student_in_group(
  p_student_id UUID,
  p_group_id UUID,
  p_total_minor BIGINT DEFAULT NULL,
  p_discount_minor BIGINT DEFAULT 0,
  p_currency TEXT DEFAULT 'EGP',
  p_due_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  g_rec RECORD;
  current_active_count INT;
  s_status TEXT;
  v_enrollment_id UUID;
  v_invoice_id UUID;
  v_final_minor BIGINT;
  v_due_at TIMESTAMPTZ;
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('enrollments.manage')
    OR public.has_permission('groups.manage')
    OR public.current_user_role() IN ('admin', 'super_admin', 'staff')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to enroll student' USING ERRCODE = '42501';
  END IF;

  SELECT status INTO s_status FROM public.students WHERE id = p_student_id;
  IF s_status IS NULL THEN
    RAISE EXCEPTION 'Student record not found' USING ERRCODE = 'P0002';
  END IF;
  IF s_status <> 'active' THEN
    RAISE EXCEPTION 'Cannot enroll inactive student' USING ERRCODE = '22023';
  END IF;

  SELECT id, name, max_capacity, capacity, status INTO g_rec
  FROM public.groups
  WHERE id = p_group_id
  FOR UPDATE;

  IF g_rec.id IS NULL THEN
    RAISE EXCEPTION 'Group record not found' USING ERRCODE = 'P0002';
  END IF;
  IF g_rec.status <> 'active' THEN
    RAISE EXCEPTION 'Cannot enroll into inactive group' USING ERRCODE = '22023';
  END IF;

  SELECT COUNT(*)::INT INTO current_active_count
  FROM public.enrollments
  WHERE group_id = p_group_id AND status = 'active';

  IF COALESCE(g_rec.max_capacity, g_rec.capacity) IS NOT NULL
     AND current_active_count >= COALESCE(g_rec.max_capacity, g_rec.capacity)
     AND NOT EXISTS (
       SELECT 1 FROM public.enrollments
       WHERE student_id = p_student_id AND group_id = p_group_id AND status = 'active'
     ) THEN
    RAISE EXCEPTION 'Group capacity exceeded' USING ERRCODE = '54000';
  END IF;

  v_final_minor := GREATEST(0, COALESCE(p_total_minor, 0) - GREATEST(0, COALESCE(p_discount_minor, 0)));
  v_due_at := COALESCE(p_due_at, NOW() + INTERVAL '7 days');

  INSERT INTO public.enrollments (
    student_id,
    group_id,
    status,
    start_date,
    access_status,
    payment_status,
    base_price_minor,
    discount_minor,
    final_price_minor,
    payment_exempt,
    activated_at
  )
  VALUES (
    p_student_id,
    p_group_id,
    'active',
    CURRENT_DATE,
    CASE WHEN v_final_minor > 0 THEN 'pending_payment' ELSE 'active' END,
    CASE WHEN v_final_minor > 0 THEN 'pending_payment' ELSE 'exempt' END,
    GREATEST(0, COALESCE(p_total_minor, 0)),
    GREATEST(0, COALESCE(p_discount_minor, 0)),
    v_final_minor,
    v_final_minor = 0,
    CASE WHEN v_final_minor = 0 THEN NOW() ELSE NULL END
  )
  ON CONFLICT (student_id, group_id) WHERE status = 'active' DO UPDATE SET
    start_date = CURRENT_DATE,
    end_date = NULL,
    access_status = EXCLUDED.access_status,
    payment_status = EXCLUDED.payment_status,
    base_price_minor = EXCLUDED.base_price_minor,
    discount_minor = EXCLUDED.discount_minor,
    final_price_minor = EXCLUDED.final_price_minor,
    payment_exempt = EXCLUDED.payment_exempt,
    activated_at = EXCLUDED.activated_at,
    updated_at = NOW()
  RETURNING id INTO v_enrollment_id;

  IF v_final_minor > 0 THEN
    INSERT INTO public.invoices (
      student_id,
      enrollment_id,
      group_id,
      currency,
      subtotal_minor,
      discount_minor,
      total_minor,
      amount_paid_minor,
      status,
      due_at
    )
    VALUES (
      p_student_id,
      v_enrollment_id,
      p_group_id,
      COALESCE(NULLIF(p_currency, ''), 'EGP'),
      GREATEST(0, COALESCE(p_total_minor, 0)),
      GREATEST(0, COALESCE(p_discount_minor, 0)),
      v_final_minor,
      0,
      'issued',
      v_due_at
    )
    RETURNING id INTO v_invoice_id;

    INSERT INTO public.invoice_items (
      invoice_id,
      description,
      quantity,
      unit_amount_minor,
      total_minor
    )
    VALUES (
      v_invoice_id,
      'قيد واشتراك مجموعة: ' || COALESCE(g_rec.name, p_group_id::TEXT),
      1,
      v_final_minor,
      v_final_minor
    );

    UPDATE public.enrollments
    SET activation_invoice_id = v_invoice_id,
        updated_at = NOW()
    WHERE id = v_enrollment_id;

    PERFORM public.notify_payment_required(p_student_id, p_group_id, v_invoice_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'enrollment_id', v_enrollment_id,
    'invoice_id', v_invoice_id,
    'due_at', v_due_at,
    'requires_payment', v_final_minor > 0,
    'access_status', CASE WHEN v_final_minor > 0 THEN 'pending_payment' ELSE 'active' END,
    'message', CASE
      WHEN v_final_minor > 0 THEN 'Student enrolled. Content is pending cash payment.'
      ELSE 'Student enrolled successfully with full active access.'
    END
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.enroll_student_in_group(UUID, UUID, BIGINT, BIGINT, TEXT, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enroll_student_in_group(UUID, UUID, BIGINT, BIGINT, TEXT, TIMESTAMPTZ) TO authenticated, service_role;


-- ============================================================================
-- Helpdesk Notifications and Reply Triggers (20261019153000)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.add_ticket_reply(
  p_ticket_id UUID,
  p_message TEXT
)
RETURNS public.ticket_replies
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ticket public.support_tickets%ROWTYPE;
  v_teacher_id UUID;
  inserted_reply public.ticket_replies%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NULLIF(trim(p_message), '') IS NULL THEN
    RAISE EXCEPTION 'Reply message is required';
  END IF;

  SELECT * INTO v_ticket
  FROM public.support_tickets
  WHERE id = p_ticket_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ticket does not exist';
  END IF;

  IF v_ticket.status = 'closed' THEN
    RAISE EXCEPTION 'Cannot reply to a closed ticket';
  END IF;

  v_teacher_id := public.current_teacher_id();

  IF NOT (
    v_ticket.user_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    OR (v_teacher_id IS NOT NULL AND v_ticket.assigned_teacher_id = v_teacher_id)
    OR (v_ticket.group_id IS NOT NULL AND public.current_teacher_assigned_to_group(v_ticket.group_id))
    OR (
      v_teacher_id IS NOT NULL AND EXISTS (
        SELECT 1
        FROM public.enrollments e
        JOIN public.students s ON s.id = e.student_id
        WHERE s.profile_id = v_ticket.user_id
          AND public.current_teacher_assigned_to_group(e.group_id)
      )
    )
    OR (
      v_ticket.group_id IS NOT NULL AND EXISTS (
        SELECT 1
        FROM public.parents p
        JOIN public.parent_students ps ON ps.parent_id = p.id
        JOIN public.enrollments e ON e.student_id = ps.student_id
        WHERE p.profile_id = auth.uid()
          AND e.group_id = v_ticket.group_id
          AND e.status = 'active'
      )
    )
  ) THEN
    RAISE EXCEPTION 'You are not allowed to reply to this ticket';
  END IF;

  INSERT INTO public.ticket_replies (ticket_id, user_id, message, created_at)
  VALUES (p_ticket_id, auth.uid(), trim(p_message), NOW())
  RETURNING * INTO inserted_reply;

  UPDATE public.support_tickets
  SET updated_at = NOW(),
      status = CASE WHEN status = 'open' THEN 'in_progress' ELSE status END,
      assigned_teacher_id = CASE
        WHEN assigned_teacher_id IS NULL AND v_teacher_id IS NOT NULL THEN v_teacher_id
        ELSE assigned_teacher_id
      END
  WHERE id = p_ticket_id;

  RETURN inserted_reply;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_support_ticket_status(
  p_ticket_id UUID,
  p_status TEXT
)
RETURNS public.support_tickets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ticket public.support_tickets%ROWTYPE;
  v_teacher_id UUID;
  updated_ticket public.support_tickets%ROWTYPE;
  clean_status TEXT := COALESCE(NULLIF(trim(p_status), ''), 'open');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF clean_status NOT IN ('open', 'in_progress', 'resolved', 'closed', 'pending') THEN
    RAISE EXCEPTION 'Invalid ticket status';
  END IF;

  SELECT * INTO v_ticket
  FROM public.support_tickets
  WHERE id = p_ticket_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ticket does not exist';
  END IF;

  v_teacher_id := public.current_teacher_id();

  IF NOT (
    v_ticket.user_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    OR (v_teacher_id IS NOT NULL AND v_ticket.assigned_teacher_id = v_teacher_id)
    OR (v_ticket.group_id IS NOT NULL AND public.current_teacher_assigned_to_group(v_ticket.group_id))
    OR (
      v_teacher_id IS NOT NULL AND EXISTS (
        SELECT 1
        FROM public.enrollments e
        JOIN public.students s ON s.id = e.student_id
        WHERE s.profile_id = v_ticket.user_id
          AND public.current_teacher_assigned_to_group(e.group_id)
      )
    )
  ) THEN
    RAISE EXCEPTION 'You are not allowed to update this ticket';
  END IF;

  UPDATE public.support_tickets
  SET status = clean_status,
      updated_at = NOW(),
      assigned_teacher_id = CASE
        WHEN assigned_teacher_id IS NULL AND v_teacher_id IS NOT NULL THEN v_teacher_id
        ELSE assigned_teacher_id
      END
  WHERE id = p_ticket_id
  RETURNING * INTO updated_ticket;

  RETURN updated_ticket;
END;
$$;

CREATE OR REPLACE FUNCTION public.trigger_notify_on_support_ticket_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.assigned_teacher_id IS NOT NULL THEN
    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
    SELECT t.profile_id,
           'تذكرة دعم فني جديدة 🎫',
           'تم فتح تذكرة جديدة: "' || NEW.subject || '"',
           'ticket',
           NEW.id
    FROM public.teachers t
    WHERE t.id = NEW.assigned_teacher_id
      AND t.profile_id IS NOT NULL
      AND t.profile_id <> NEW.user_id;
  ELSIF NEW.group_id IS NOT NULL THEN
    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
    SELECT DISTINCT t.profile_id,
           'تذكرة دعم فني جديدة 🎫',
           'تم فتح تذكرة جديدة لمجموعتك: "' || NEW.subject || '"',
           'ticket',
           NEW.id
    FROM public.group_teachers gt
    JOIN public.teachers t ON t.id = gt.teacher_id
    WHERE gt.group_id = NEW.group_id
      AND t.profile_id IS NOT NULL
      AND t.profile_id <> NEW.user_id;
  END IF;

  INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
  SELECT p.id,
         'تذكرة دعم جديدة في السنتر 🎫',
         'تذكرة جديدة بعنوان: "' || NEW.subject || '"',
         'ticket',
         NEW.id
  FROM public.profiles p
  WHERE p.role IN ('admin', 'staff', 'super_admin')
    AND p.id <> NEW.user_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_notify_support_ticket_created ON public.support_tickets;
CREATE TRIGGER tr_notify_support_ticket_created
AFTER INSERT ON public.support_tickets
FOR EACH ROW
EXECUTE FUNCTION public.trigger_notify_on_support_ticket_created();

CREATE OR REPLACE FUNCTION public.trigger_notify_on_ticket_reply_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ticket public.support_tickets%ROWTYPE;
  v_short_msg TEXT;
BEGIN
  SELECT * INTO v_ticket
  FROM public.support_tickets
  WHERE id = NEW.ticket_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  v_short_msg := SUBSTRING(NEW.message FROM 1 FOR 90);

  IF NEW.user_id <> v_ticket.user_id THEN
    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
    VALUES (
      v_ticket.user_id,
      'رد جديد على تذكرتك 💬',
      'وصلك رد جديد على التذكرة "' || v_ticket.subject || '": ' || v_short_msg,
      'ticket',
      v_ticket.id
    );

    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
    SELECT DISTINCT p.profile_id,
           'رد على تذكرة ابنك/ابنتك 💬',
           'تم الرد على تذكرة الطالب "' || v_ticket.subject || '": ' || v_short_msg,
           'ticket',
           v_ticket.id
    FROM public.students s
    JOIN public.parent_students ps ON ps.student_id = s.id
    JOIN public.parents p ON p.id = ps.parent_id
    WHERE s.profile_id = v_ticket.user_id
      AND p.profile_id IS NOT NULL
      AND p.profile_id <> NEW.user_id;
  ELSE
    IF v_ticket.assigned_teacher_id IS NOT NULL THEN
      INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
      SELECT t.profile_id,
             'رد جديد من صاحب التذكرة 💬',
             'رد جديد على التذكرة "' || v_ticket.subject || '": ' || v_short_msg,
             'ticket',
             v_ticket.id
      FROM public.teachers t
      WHERE t.id = v_ticket.assigned_teacher_id
        AND t.profile_id IS NOT NULL
        AND t.profile_id <> NEW.user_id;
    ELSIF v_ticket.group_id IS NOT NULL THEN
      INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
      SELECT DISTINCT t.profile_id,
             'رد جديد من صاحب التذكرة 💬',
             'رد جديد على التذكرة "' || v_ticket.subject || '": ' || v_short_msg,
             'ticket',
             v_ticket.id
      FROM public.group_teachers gt
      JOIN public.teachers t ON t.id = gt.teacher_id
      WHERE gt.group_id = v_ticket.group_id
        AND t.profile_id IS NOT NULL
        AND t.profile_id <> NEW.user_id;
    END IF;

    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
    SELECT pr.id,
           'رد جديد على تذكرة دعم 💬',
           'رد جديد من المستخدم على "' || v_ticket.subject || '": ' || v_short_msg,
           'ticket',
           v_ticket.id
    FROM public.profiles pr
    WHERE pr.role IN ('admin', 'staff', 'super_admin')
      AND pr.id <> NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_notify_ticket_reply_created ON public.ticket_replies;
CREATE TRIGGER tr_notify_ticket_reply_created
AFTER INSERT ON public.ticket_replies
FOR EACH ROW
EXECUTE FUNCTION public.trigger_notify_on_ticket_reply_created();

CREATE OR REPLACE FUNCTION public.trigger_notify_on_ticket_status_changed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status_ar TEXT;
  v_changer_id UUID := auth.uid();
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    v_status_ar := CASE NEW.status
      WHEN 'open' THEN 'مفتوحة'
      WHEN 'in_progress' THEN 'قيد المتابعة'
      WHEN 'resolved' THEN 'تم الحل بنجاح'
      WHEN 'closed' THEN 'مغلقة'
      ELSE NEW.status
    END;

    IF v_changer_id IS NULL OR v_changer_id <> NEW.user_id THEN
      INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
      VALUES (
        NEW.user_id,
        'تحديث حالة تذكرة الدعم 🔄',
        'تم تغيير حالة تذكرتك "' || NEW.subject || '" إلى (' || v_status_ar || ').',
        'ticket',
        NEW.id
      );

      INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
      SELECT DISTINCT p.profile_id,
             'تحديث حالة تذكرة ابنك/ابنتك 🔄',
             'تم تغيير حالة التذكرة "' || NEW.subject || '" إلى (' || v_status_ar || ').',
             'ticket',
             NEW.id
      FROM public.students s
      JOIN public.parent_students ps ON ps.student_id = s.id
      JOIN public.parents p ON p.id = ps.parent_id
      WHERE s.profile_id = NEW.user_id
        AND p.profile_id IS NOT NULL
        AND (v_changer_id IS NULL OR p.profile_id <> v_changer_id);
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_notify_ticket_status_changed ON public.support_tickets;
CREATE TRIGGER tr_notify_ticket_status_changed
AFTER UPDATE OF status ON public.support_tickets
FOR EACH ROW
EXECUTE FUNCTION public.trigger_notify_on_ticket_status_changed();

GRANT EXECUTE ON FUNCTION public.add_ticket_reply(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_support_ticket_status(UUID, TEXT) TO authenticated;
