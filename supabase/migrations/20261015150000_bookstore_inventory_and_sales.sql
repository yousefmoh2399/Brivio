-- Migration: 20261015150000_bookstore_inventory_and_sales.sql
-- Description: Persistent Bookstore Inventory and Sales Tracking with Multi-Tenant Isolation

-- 1. Bookstore Items / Booklets Inventory Table
CREATE TABLE IF NOT EXISTS public.bookstore_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    center_id UUID REFERENCES public.educational_centers(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    teacher TEXT NOT NULL DEFAULT 'السنتر',
    price NUMERIC(10, 2) NOT NULL DEFAULT 40.0,
    stock INT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Bookstore Sales History Table
CREATE TABLE IF NOT EXISTS public.bookstore_sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    center_id UUID REFERENCES public.educational_centers(id) ON DELETE SET NULL,
    receipt_number TEXT NOT NULL,
    student_id UUID REFERENCES public.students(id) ON DELETE SET NULL,
    student_name TEXT NOT NULL,
    student_code TEXT NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    cashier_name TEXT,
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Enable RLS
ALTER TABLE public.bookstore_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookstore_sales ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
DROP POLICY IF EXISTS "Bookstore items tenant select" ON public.bookstore_items;
CREATE POLICY "Bookstore items tenant select" ON public.bookstore_items
FOR SELECT TO authenticated
USING (
    center_id IS NULL OR
    center_id = public.current_user_center_id() OR
    public.is_super_admin()
);

DROP POLICY IF EXISTS "Bookstore items tenant insert" ON public.bookstore_items;
CREATE POLICY "Bookstore items tenant insert" ON public.bookstore_items
FOR INSERT TO authenticated
WITH CHECK (
    center_id IS NULL OR
    center_id = public.current_user_center_id() OR
    public.is_super_admin()
);

DROP POLICY IF EXISTS "Bookstore items tenant update" ON public.bookstore_items;
CREATE POLICY "Bookstore items tenant update" ON public.bookstore_items
FOR UPDATE TO authenticated
USING (
    center_id IS NULL OR
    center_id = public.current_user_center_id() OR
    public.is_super_admin()
);

DROP POLICY IF EXISTS "Bookstore items tenant delete" ON public.bookstore_items;
CREATE POLICY "Bookstore items tenant delete" ON public.bookstore_items
FOR DELETE TO authenticated
USING (
    center_id IS NULL OR
    center_id = public.current_user_center_id() OR
    public.is_super_admin()
);

DROP POLICY IF EXISTS "Bookstore sales tenant access" ON public.bookstore_sales;
CREATE POLICY "Bookstore sales tenant access" ON public.bookstore_sales
FOR ALL TO authenticated
USING (
    center_id IS NULL OR
    center_id = public.current_user_center_id() OR
    public.is_super_admin()
)
WITH CHECK (
    center_id IS NULL OR
    center_id = public.current_user_center_id() OR
    public.is_super_admin()
);

-- 5. Receipts & Payment Transactions Policies (Ensure authenticated staff/admin can insert cash sales)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'receipts' AND policyname = 'Authenticated staff can insert receipts'
    ) THEN
        CREATE POLICY "Authenticated staff can insert receipts" ON public.receipts
        FOR INSERT TO authenticated WITH CHECK (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'payment_transactions' AND policyname = 'Authenticated staff can insert payment transactions'
    ) THEN
        CREATE POLICY "Authenticated staff can insert payment transactions" ON public.payment_transactions
        FOR INSERT TO authenticated WITH CHECK (true);
    END IF;
END $$;
