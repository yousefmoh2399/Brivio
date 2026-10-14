-- Migration: 20261014130000_admin_settings_rpc.sql
-- Description: Create admin_settings table, get_admin_setting RPC, and set_admin_setting RPC

-- 1. Create admin_settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.admin_settings (
    setting_key TEXT PRIMARY KEY,
    setting_value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Enable RLS
ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;

-- Allow authenticated and anon users to view settings
DROP POLICY IF EXISTS "Anyone authenticated or anon can read admin settings" ON public.admin_settings;
CREATE POLICY "Anyone authenticated or anon can read admin settings"
    ON public.admin_settings
    FOR SELECT
    TO authenticated, anon
    USING (true);

-- Allow admins to insert/update settings
DROP POLICY IF EXISTS "Admins can update admin settings" ON public.admin_settings;
CREATE POLICY "Admins can update admin settings"
    ON public.admin_settings
    FOR ALL
    TO authenticated
    USING (public.is_admin_or_super())
    WITH CHECK (public.is_admin_or_super());

-- 2. Function: get_admin_setting(setting_key TEXT)
CREATE OR REPLACE FUNCTION public.get_admin_setting(setting_key TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_val JSONB;
BEGIN
    SELECT setting_value INTO v_val
    FROM public.admin_settings
    WHERE admin_settings.setting_key = $1;

    RETURN v_val;
END;
$$;

-- Grant execution to authenticated and anon
GRANT EXECUTE ON FUNCTION public.get_admin_setting(TEXT) TO authenticated, anon;

-- 3. Function: set_admin_setting(setting_key TEXT, setting_value JSONB)
CREATE OR REPLACE FUNCTION public.set_admin_setting(setting_key TEXT, setting_value JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.admin_settings (setting_key, setting_value, updated_at, updated_by)
    VALUES ($1, $2, NOW(), auth.uid())
    ON CONFLICT (setting_key)
    DO UPDATE SET
        setting_value = EXCLUDED.setting_value,
        updated_at = NOW(),
        updated_by = auth.uid();
END;
$$;

-- Grant execution to authenticated
GRANT EXECUTE ON FUNCTION public.set_admin_setting(TEXT, JSONB) TO authenticated;

-- 4. Overload for TEXT inputs: set_admin_setting(setting_key TEXT, setting_value TEXT)
CREATE OR REPLACE FUNCTION public.set_admin_setting(setting_key TEXT, setting_value TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.admin_settings (setting_key, setting_value, updated_at, updated_by)
    VALUES ($1, to_jsonb($2), NOW(), auth.uid())
    ON CONFLICT (setting_key)
    DO UPDATE SET
        setting_value = EXCLUDED.setting_value,
        updated_at = NOW(),
        updated_by = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_admin_setting(TEXT, TEXT) TO authenticated;

-- 5. Function: get_academy_core_summary() (Resilient Core Dashboard Counters)
CREATE OR REPLACE FUNCTION public.get_academy_core_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    b_count INT := 0;
    s_count INT := 0;
    t_count INT := 0;
    sub_count INT := 0;
    g_count INT := 0;
    today_sched_count INT := 0;
    result JSONB;
BEGIN
    BEGIN
        SELECT COUNT(*)::int INTO b_count FROM public.branches WHERE status = 'active';
    EXCEPTION WHEN OTHERS THEN
        b_count := 0;
    END;

    BEGIN
        SELECT COUNT(*)::int INTO s_count FROM public.students WHERE status = 'active';
    EXCEPTION WHEN OTHERS THEN
        s_count := 0;
    END;

    BEGIN
        SELECT COUNT(*)::int INTO t_count FROM public.teachers;
    EXCEPTION WHEN OTHERS THEN
        t_count := 0;
    END;

    BEGIN
        SELECT COUNT(*)::int INTO sub_count FROM public.subjects WHERE status = 'active';
    EXCEPTION WHEN OTHERS THEN
        sub_count := 0;
    END;

    BEGIN
        SELECT COUNT(*)::int INTO g_count FROM public.groups WHERE status = 'active';
    EXCEPTION WHEN OTHERS THEN
        g_count := 0;
    END;

    BEGIN
        SELECT COUNT(*)::int INTO today_sched_count FROM public.schedules WHERE day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::int AND status = 'active';
    EXCEPTION WHEN OTHERS THEN
        today_sched_count := 0;
    END;

    result := jsonb_build_object(
        'active_branches', b_count,
        'active_students', s_count,
        'active_teachers', t_count,
        'active_subjects', sub_count,
        'active_groups', g_count,
        'today_scheduled_classes', today_sched_count
    );

    RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_academy_core_summary() TO authenticated, anon;
