-- Migration: 20261019150000_center_financial_cycle_and_reschedule.sql
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
