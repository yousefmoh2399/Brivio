-- Migration: 20261019160000_staff_role_permissions_and_rls.sql
-- Description: Authorize staff role across center operations, grant all operational permissions, and ensure RLS policies include staff.

-- 1. Update is_admin_or_super() to include staff for center operations
CREATE OR REPLACE FUNCTION public.is_admin_or_super()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.current_user_role() IN ('admin', 'super_admin', 'staff');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.is_admin_or_super() TO authenticated;

-- 2. Update has_permission() with staff/admin operational bypass
CREATE OR REPLACE FUNCTION public.has_permission(perm_code TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    u_id UUID := auth.uid();
    user_override permission_effect;
    role_has_perm BOOLEAN := false;
BEGIN
    IF u_id IS NULL THEN
        RETURN false;
    END IF;

    -- 1. Super Admin, Admin, and Staff operational bypass
    IF public.is_admin_or_super() THEN
        RETURN true;
    END IF;

    -- 2 & 3. Check explicit user permission override
    SELECT up.effect INTO user_override
    FROM public.user_permissions up
    JOIN public.permissions p ON p.id = up.permission_id
    WHERE up.user_id = u_id AND p.code = perm_code;

    IF user_override = 'deny' THEN
        RETURN false;
    ELSIF user_override = 'grant' THEN
        RETURN true;
    END IF;

    -- 4. Check baseline role permission
    SELECT EXISTS (
        SELECT 1
        FROM public.role_permissions rp
        JOIN public.roles r ON r.id = rp.role_id
        JOIN public.permissions p ON p.id = rp.permission_id
        WHERE r.name = public.current_user_role()::text AND p.code = perm_code
    ) INTO role_has_perm;

    RETURN role_has_perm;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.has_permission(TEXT) TO authenticated;

-- 3. Update get_user_effective_permissions() to return all operational permissions for staff
CREATE OR REPLACE FUNCTION public.get_user_effective_permissions(target_user_id UUID)
RETURNS TEXT[] AS $$
DECLARE
    u_role text;
    perms TEXT[] := '{}';
BEGIN
    IF target_user_id IS NULL THEN
        RETURN perms;
    END IF;

    SELECT role::text INTO u_role FROM public.profiles WHERE id = target_user_id;
    IF u_role IS NULL THEN
        RETURN perms;
    END IF;

    IF u_role IN ('super_admin', 'admin', 'staff') THEN
        SELECT ARRAY_AGG(code) INTO perms FROM public.permissions;
        RETURN perms;
    END IF;

    SELECT ARRAY_AGG(DISTINCT code) INTO perms
    FROM (
        SELECT p.code
        FROM public.user_permissions up
        JOIN public.permissions p ON p.id = up.permission_id
        WHERE up.user_id = target_user_id AND up.effect = 'grant'

        UNION

        SELECT p.code
        FROM public.role_permissions rp
        JOIN public.roles r ON r.id = rp.role_id
        JOIN public.permissions p ON p.id = rp.permission_id
        WHERE r.name = u_role
    ) active_perms
    WHERE code NOT IN (
        SELECT p.code
        FROM public.user_permissions up
        JOIN public.permissions p ON p.id = up.permission_id
        WHERE up.user_id = target_user_id AND up.effect = 'deny'
    );

    RETURN COALESCE(perms, '{}');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_user_effective_permissions(UUID) TO authenticated;

-- 4. Seed role_permissions for staff role
DO $$
DECLARE
    r_staff_id UUID;
BEGIN
    SELECT id INTO r_staff_id FROM public.roles WHERE name = 'staff';
    IF r_staff_id IS NOT NULL THEN
        INSERT INTO public.role_permissions (role_id, permission_id)
        SELECT r_staff_id, p.id
        FROM public.permissions p
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 5. Operational RLS Policies for Staff
-- Leave Requests: Staff can view, insert, update
DROP POLICY IF EXISTS "Staff manage leave requests" ON public.leave_requests;
CREATE POLICY "Staff manage leave requests"
ON public.leave_requests FOR ALL TO authenticated
USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));

-- Compensation Requests: Staff can manage
DROP POLICY IF EXISTS "Staff manage compensation requests" ON public.compensation_requests;
CREATE POLICY "Staff manage compensation requests"
ON public.compensation_requests FOR ALL TO authenticated
USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));

-- Attendance Records: Staff can manage
DROP POLICY IF EXISTS "Staff manage attendance records" ON public.attendance_records;
CREATE POLICY "Staff manage attendance records"
ON public.attendance_records FOR ALL TO authenticated
USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));

-- Class Sessions: Staff can manage
DROP POLICY IF EXISTS "Staff manage class sessions" ON public.class_sessions;
CREATE POLICY "Staff manage class sessions"
ON public.class_sessions FOR ALL TO authenticated
USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));

-- Receipts: Staff can manage
DROP POLICY IF EXISTS "Staff manage receipts" ON public.receipts;
CREATE POLICY "Staff manage receipts"
ON public.receipts FOR ALL TO authenticated
USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));

-- Ensure Payments table exists (used by Express Cashier & Financial Ledger)
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id) ON DELETE SET NULL,
    amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    payment_type TEXT DEFAULT 'cash',
    method TEXT DEFAULT 'cash',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Payments: Staff & Admin can manage, students/parents can view their own
DROP POLICY IF EXISTS "Staff manage payments" ON public.payments;
CREATE POLICY "Staff manage payments"
ON public.payments FOR ALL TO authenticated
USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));

DROP POLICY IF EXISTS "Students and parents view own payments" ON public.payments;
CREATE POLICY "Students and parents view own payments"
ON public.payments FOR SELECT TO authenticated
USING (
    student_id IS NOT NULL AND (
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = payments.student_id AND s.profile_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = payments.student_id AND public.current_parent_has_student(s.id))
    )
);

-- Payment Transactions & Attempts (conditionally applied if present in schema)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'payment_transactions') THEN
        DROP POLICY IF EXISTS "Staff manage payment transactions" ON public.payment_transactions;
        CREATE POLICY "Staff manage payment transactions"
        ON public.payment_transactions FOR ALL TO authenticated
        USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
        WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));
    END IF;

    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'payment_attempts') THEN
        DROP POLICY IF EXISTS "Staff manage payment attempts" ON public.payment_attempts;
        CREATE POLICY "Staff manage payment attempts"
        ON public.payment_attempts FOR ALL TO authenticated
        USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
        WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));
    END IF;
END $$;

-- Invoices: Staff can manage
DROP POLICY IF EXISTS "Staff manage invoices" ON public.invoices;
CREATE POLICY "Staff manage invoices"
ON public.invoices FOR ALL TO authenticated
USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));

-- Invoice items: Staff can manage
DROP POLICY IF EXISTS "Staff manage invoice items" ON public.invoice_items;
CREATE POLICY "Staff manage invoice items"
ON public.invoice_items FOR ALL TO authenticated
USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));

-- Support Tickets: Staff can manage
DROP POLICY IF EXISTS "Staff manage support tickets" ON public.support_tickets;
CREATE POLICY "Staff manage support tickets"
ON public.support_tickets FOR ALL TO authenticated
USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));

-- Ticket Replies: Staff can insert and view
DROP POLICY IF EXISTS "Staff manage ticket replies" ON public.ticket_replies;
CREATE POLICY "Staff manage ticket replies"
ON public.ticket_replies FOR ALL TO authenticated
USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));

-- Rooms: Add seat_allocations column and ensure staff can manage rooms
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS seat_allocations JSONB DEFAULT '{}'::jsonb;

DROP POLICY IF EXISTS "Staff manage rooms" ON public.rooms;
CREATE POLICY "Staff manage rooms"
ON public.rooms FOR ALL TO authenticated
USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'))
WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));

