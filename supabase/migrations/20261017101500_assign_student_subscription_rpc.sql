-- Migration: 20261017101500_assign_student_subscription_rpc.sql
-- Description: Implement assign_student_subscription RPC supporting all parameter variations,
-- auto-generating student subscriptions, installments, and invoices, with audit logging and RLS policies.

-- 1. Ensure required sequences and columns exist
CREATE SEQUENCE IF NOT EXISTS public.invoice_number_seq START WITH 10001;
CREATE SEQUENCE IF NOT EXISTS public.receipt_number_seq START WITH 50001;

ALTER TABLE public.subscription_plans
  ADD COLUMN IF NOT EXISTS center_id UUID REFERENCES public.educational_centers(id) ON DELETE SET NULL;

ALTER TABLE public.student_subscriptions
  ADD COLUMN IF NOT EXISTS center_id UUID REFERENCES public.educational_centers(id) ON DELETE SET NULL;

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS center_id UUID REFERENCES public.educational_centers(id) ON DELETE SET NULL;

ALTER TABLE public.receipts
  ADD COLUMN IF NOT EXISTS center_id UUID REFERENCES public.educational_centers(id) ON DELETE SET NULL;

ALTER TABLE public.payment_transactions
  ADD COLUMN IF NOT EXISTS center_id UUID REFERENCES public.educational_centers(id) ON DELETE SET NULL;

-- 2. Ensure RLS policies permit admin/staff management of subscriptions and invoices
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'student_subscriptions' AND policyname = 'Student subscriptions manageable by staff'
  ) THEN
    CREATE POLICY "Student subscriptions manageable by staff"
    ON public.student_subscriptions FOR ALL TO authenticated
    USING (
      public.is_admin_or_super() 
      OR public.has_permission('subscriptions.manage') 
      OR public.has_permission('payments.collect')
      OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    )
    WITH CHECK (
      public.is_admin_or_super() 
      OR public.has_permission('subscriptions.manage') 
      OR public.has_permission('payments.collect')
      OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'subscription_installments' AND policyname = 'Subscription installments manageable by staff'
  ) THEN
    CREATE POLICY "Subscription installments manageable by staff"
    ON public.subscription_installments FOR ALL TO authenticated
    USING (
      public.is_admin_or_super() 
      OR public.has_permission('subscriptions.manage') 
      OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    )
    WITH CHECK (
      public.is_admin_or_super() 
      OR public.has_permission('subscriptions.manage') 
      OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'invoices' AND policyname = 'Invoices manageable by staff'
  ) THEN
    CREATE POLICY "Invoices manageable by staff"
    ON public.invoices FOR ALL TO authenticated
    USING (
      public.is_admin_or_super() 
      OR public.has_permission('invoices.manage') 
      OR public.has_permission('payments.collect')
      OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    )
    WITH CHECK (
      public.is_admin_or_super() 
      OR public.has_permission('invoices.manage') 
      OR public.has_permission('payments.collect')
      OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'invoice_items' AND policyname = 'Invoice items manageable by staff'
  ) THEN
    CREATE POLICY "Invoice items manageable by staff"
    ON public.invoice_items FOR ALL TO authenticated
    USING (
      public.is_admin_or_super() 
      OR public.has_permission('invoices.manage') 
      OR public.has_permission('payments.collect')
      OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    )
    WITH CHECK (
      public.is_admin_or_super() 
      OR public.has_permission('invoices.manage') 
      OR public.has_permission('payments.collect')
      OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    );
  END IF;
END;
$$;

-- 3. Core Function: assign_student_subscription supporting both p_plan_id and p_subscription_plan_id
CREATE OR REPLACE FUNCTION public.assign_student_subscription(
    p_student_id UUID,
    p_plan_id UUID DEFAULT NULL,
    p_subscription_plan_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_target_plan_id UUID;
    v_plan RECORD;
    v_student RECORD;
    v_center_id UUID;
    v_subscription_id UUID;
    v_invoice_id UUID;
    v_invoice_number TEXT;
    v_installment_count INT;
    v_base_installment BIGINT;
    v_first_installment BIGINT;
    i INT;
BEGIN
    -- Determine which plan argument was passed
    v_target_plan_id := COALESCE(p_plan_id, p_subscription_plan_id);
    IF v_target_plan_id IS NULL THEN
        RAISE EXCEPTION 'Plan ID is required (p_plan_id or p_subscription_plan_id)' USING ERRCODE = '22023';
    END IF;

    IF p_student_id IS NULL THEN
        RAISE EXCEPTION 'Student ID is required' USING ERRCODE = '22023';
    END IF;

    -- Verify permissions
    IF NOT (
        public.is_admin_or_super()
        OR public.has_permission('subscriptions.manage')
        OR public.has_permission('invoices.manage')
        OR public.has_permission('payments.collect')
        OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    ) THEN
        RAISE EXCEPTION 'Unauthorized to assign subscription' USING ERRCODE = '42501';
    END IF;

    -- Fetch Student
    SELECT s.*, p.center_id AS profile_center_id
    INTO v_student
    FROM public.students s
    LEFT JOIN public.profiles p ON p.id = s.profile_id
    WHERE s.id = p_student_id;

    IF v_student.id IS NULL THEN
        RAISE EXCEPTION 'Student not found: %', p_student_id USING ERRCODE = '22023';
    END IF;

    -- Fetch Plan
    SELECT *
    INTO v_plan
    FROM public.subscription_plans
    WHERE id = v_target_plan_id AND status = 'active';

    IF v_plan.id IS NULL THEN
        RAISE EXCEPTION 'Active subscription plan not found: %', v_target_plan_id USING ERRCODE = '22023';
    END IF;

    -- Determine Center ID
    v_center_id := COALESCE(
        v_student.profile_center_id,
        (SELECT b.center_id FROM public.branches b WHERE b.id = v_student.primary_branch_id LIMIT 1),
        public.current_user_center_id()
    );

    -- Insert into student_subscriptions
    INSERT INTO public.student_subscriptions (
        student_id,
        plan_id,
        agreed_total_minor,
        currency,
        start_date,
        end_date,
        status,
        created_by
    )
    VALUES (
        p_student_id,
        v_target_plan_id,
        v_plan.total_amount_minor,
        COALESCE(v_plan.currency, 'EGP'),
        CURRENT_DATE,
        CURRENT_DATE + INTERVAL '1 year',
        'active',
        auth.uid()
    )
    RETURNING id INTO v_subscription_id;

    -- Update center_id if column exists
    IF v_center_id IS NOT NULL THEN
        BEGIN
            UPDATE public.student_subscriptions
            SET center_id = v_center_id
            WHERE id = v_subscription_id;
        EXCEPTION WHEN undefined_column THEN
            NULL;
        END;
    END IF;

    -- Generate Installments if billing_type is installment
    v_installment_count := COALESCE(v_plan.installment_count, 1);
    IF v_plan.billing_type = 'installment' AND v_installment_count > 1 THEN
        v_base_installment := v_plan.total_amount_minor / v_installment_count;
        v_first_installment := v_plan.total_amount_minor - (v_base_installment * (v_installment_count - 1));

        FOR i IN 1..v_installment_count LOOP
            INSERT INTO public.subscription_installments (
                subscription_id,
                sequence,
                due_date,
                amount_minor,
                status
            )
            VALUES (
                v_subscription_id,
                i,
                CURRENT_DATE + ((i - 1) * INTERVAL '1 month'),
                CASE WHEN i = 1 THEN v_first_installment ELSE v_base_installment END,
                'pending'
            );
        END LOOP;
    END IF;

    -- Create Invoice
    INSERT INTO public.invoices (
        student_id,
        subscription_id,
        currency,
        subtotal_minor,
        discount_minor,
        total_minor,
        amount_paid_minor,
        status,
        due_at,
        issued_at
    )
    VALUES (
        p_student_id,
        v_subscription_id,
        COALESCE(v_plan.currency, 'EGP'),
        v_plan.total_amount_minor,
        0,
        v_plan.total_amount_minor,
        0,
        'issued',
        NOW() + INTERVAL '7 days',
        NOW()
    )
    RETURNING id, invoice_number INTO v_invoice_id, v_invoice_number;

    -- Update center_id on invoice if column exists
    IF v_center_id IS NOT NULL THEN
        BEGIN
            UPDATE public.invoices
            SET center_id = v_center_id
            WHERE id = v_invoice_id;
        EXCEPTION WHEN undefined_column THEN
            NULL;
        END;
    END IF;

    -- Insert Invoice Line Item
    INSERT INTO public.invoice_items (
        invoice_id,
        description,
        quantity,
        unit_amount_minor,
        total_minor
    )
    VALUES (
        v_invoice_id,
        'اشتراك: ' || v_plan.name,
        1,
        v_plan.total_amount_minor,
        v_plan.total_amount_minor
    );

    -- Record Audit Log if audit_logs table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'audit_logs') THEN
        BEGIN
            INSERT INTO public.audit_logs (
                actor_id,
                table_name,
                record_id,
                action,
                new_data
            )
            VALUES (
                auth.uid(),
                'student_subscriptions',
                v_subscription_id,
                'insert',
                jsonb_build_object(
                    'student_id', p_student_id,
                    'student_name', v_student.full_name,
                    'student_code', v_student.student_code,
                    'plan_id', v_target_plan_id,
                    'plan_name', v_plan.name,
                    'total_amount_minor', v_plan.total_amount_minor,
                    'invoice_id', v_invoice_id,
                    'invoice_number', v_invoice_number
                )
            );
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم تسكين اشتراك الطالب وتوليد الفاتورة بنجاح',
        'subscription_id', v_subscription_id,
        'invoice_id', v_invoice_id,
        'invoice_number', v_invoice_number,
        'total_amount_minor', v_plan.total_amount_minor,
        'currency', COALESCE(v_plan.currency, 'EGP')
    );
END;
$$;

-- 4. Overload for single JSON/JSONB payload support (guarantees PostgREST compatibility under all call shapes)
CREATE OR REPLACE FUNCTION public.assign_student_subscription(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN public.assign_student_subscription(
        (p_payload->>'p_student_id')::UUID,
        NULLIF(p_payload->>'p_plan_id', '')::UUID,
        NULLIF(p_payload->>'p_subscription_plan_id', '')::UUID
    );
END;
$$;

-- 5. Permissions
REVOKE EXECUTE ON FUNCTION public.assign_student_subscription(UUID, UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assign_student_subscription(UUID, UUID, UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.assign_student_subscription(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assign_student_subscription(JSONB) TO authenticated;

-- 6. Reload schema cache for PostgREST
NOTIFY pgrst, 'reload schema';
