-- Migration: 20261018113000_teacher_bookstore_and_settlement_integration.sql
-- Description: Link bookstore items and sales to teachers, and fix teacher financial overview calculations

-- 1. Add teacher_id to bookstore_items if not exists
ALTER TABLE public.bookstore_items
  ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_bookstore_items_teacher_id
  ON public.bookstore_items(teacher_id);

-- 2. Add teacher_id to bookstore_sales if not exists
ALTER TABLE public.bookstore_sales
  ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_bookstore_sales_teacher_id
  ON public.bookstore_sales(teacher_id);

-- 3. Robust get_teacher_financial_overview with accurate payment handling
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
  v_teacher_profile_id UUID := NULL;
BEGIN
  -- Resolve teacher id (supports teachers.id or profiles.id / auth.uid())
  IF v_teacher_id IS NOT NULL THEN
    SELECT t.id, t.profile_id
    INTO v_teacher_id, v_teacher_profile_id
    FROM public.teachers t
    WHERE t.id = v_teacher_id OR t.profile_id = v_teacher_id
    LIMIT 1;
  ELSE
    v_teacher_id := public.current_teacher_id();
    IF v_teacher_id IS NOT NULL THEN
      SELECT t.profile_id INTO v_teacher_profile_id
      FROM public.teachers t WHERE t.id = v_teacher_id;
    END IF;
  END IF;

  IF v_teacher_id IS NULL THEN
    -- If still null, try finding teacher for current auth user
    SELECT t.id, t.profile_id
    INTO v_teacher_id, v_teacher_profile_id
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
       OR (v_teacher_profile_id IS NOT NULL AND g.teacher_id = v_teacher_profile_id)
       OR EXISTS (
            SELECT 1
            FROM public.group_teachers gt
            WHERE gt.group_id = g.id
              AND (gt.teacher_id = v_teacher_id OR (v_teacher_profile_id IS NOT NULL AND gt.teacher_id = v_teacher_profile_id))
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
      COALESCE(NULLIF(e.final_price_minor, 0), NULLIF(e.base_price_minor, 0), inv.total_minor, 0)::BIGINT AS final_price_minor,
      CASE
        WHEN e.payment_status = 'paid' THEN
          COALESCE(NULLIF(inv.amount_paid_minor, 0), NULLIF(e.final_price_minor, 0), NULLIF(e.base_price_minor, 0), 0)::BIGINT
        WHEN e.payment_exempt = true OR e.payment_status = 'exempt' THEN 0::BIGINT
        ELSE COALESCE(inv.amount_paid_minor, 0)::BIGINT
      END AS paid_minor,
      e.payment_status,
      e.payment_exempt
    FROM assigned_groups ag
    LEFT JOIN public.subjects s ON s.id = ag.subject_id
    LEFT JOIN public.enrollments e ON e.group_id = ag.id
    LEFT JOIN public.invoices inv ON inv.id = e.activation_invoice_id OR inv.enrollment_id = e.id
  )
  SELECT
    fr.group_id,
    fr.group_name,
    fr.group_code,
    fr.subject_name,
    COUNT(fr.enrollment_id)::BIGINT AS total_students,
    COUNT(fr.enrollment_id) FILTER (
      WHERE fr.payment_status IN ('paid', 'exempt') OR fr.payment_exempt = true OR fr.paid_minor > 0
    )::BIGINT AS paid_students,
    COUNT(fr.enrollment_id) FILTER (
      WHERE COALESCE(fr.final_price_minor, 0) > COALESCE(fr.paid_minor, 0)
        AND COALESCE(fr.payment_exempt, false) = false
        AND COALESCE(fr.payment_status, '') <> 'exempt'
        AND COALESCE(fr.payment_status, '') <> 'paid'
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

-- 4. RPC to get booklet / bookstore sales summary for a specific teacher
DROP FUNCTION IF EXISTS public.get_teacher_bookstore_sales_summary(UUID);

CREATE OR REPLACE FUNCTION public.get_teacher_bookstore_sales_summary(p_teacher_id UUID)
RETURNS TABLE (
  total_booklets_sold BIGINT,
  total_booklet_revenue NUMERIC(10, 2),
  booklet_details JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID := p_teacher_id;
  v_teacher_name TEXT := '';
BEGIN
  -- Resolve teacher id and name
  SELECT t.id, COALESCE(p.full_name, t.full_name, '')
  INTO v_teacher_id, v_teacher_name
  FROM public.teachers t
  LEFT JOIN public.profiles p ON p.id = t.profile_id
  WHERE t.id = v_teacher_id OR t.profile_id = v_teacher_id
  LIMIT 1;

  IF v_teacher_id IS NULL THEN
    RETURN QUERY SELECT 0::BIGINT, 0.00::NUMERIC(10, 2), '[]'::JSONB;
    RETURN;
  END IF;

  RETURN QUERY
  WITH sales_expanded AS (
    SELECT
      bs.id AS sale_id,
      bs.created_at,
      item->>'id' AS item_id,
      COALESCE(item->>'title', 'مذكرة') AS title,
      COALESCE((item->>'price')::NUMERIC, 0.00) AS price,
      COALESCE((item->>'quantity')::INT, 1) AS quantity,
      item->>'teacher_id' AS item_teacher_id,
      item->>'teacher' AS item_teacher_name
    FROM public.bookstore_sales bs,
    jsonb_array_elements(bs.items) AS item
    WHERE (
      item->>'teacher_id' = v_teacher_id::TEXT
      OR (v_teacher_name <> '' AND item->>'teacher' ILIKE '%' || v_teacher_name || '%')
      OR EXISTS (
        SELECT 1 FROM public.bookstore_items bi
        WHERE bi.id::TEXT = item->>'id' AND bi.teacher_id = v_teacher_id
      )
    )
  ),
  aggregated_by_title AS (
    SELECT
      se.title,
      se.price,
      SUM(se.quantity)::BIGINT AS sold_count,
      SUM(se.quantity * se.price)::NUMERIC(10, 2) AS total_revenue
    FROM sales_expanded se
    GROUP BY se.title, se.price
  )
  SELECT
    COALESCE(SUM(ab.sold_count), 0)::BIGINT AS total_booklets_sold,
    COALESCE(SUM(ab.total_revenue), 0.00)::NUMERIC(10, 2) AS total_booklet_revenue,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'title', ab.title,
          'price', ab.price,
          'sold_count', ab.sold_count,
          'total_revenue', ab.total_revenue
        )
      ),
      '[]'::JSONB
    ) AS booklet_details
  FROM aggregated_by_title ab;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_bookstore_sales_summary(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
