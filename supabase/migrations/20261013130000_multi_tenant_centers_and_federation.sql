-- Migration: 20261013130000_multi_tenant_centers_and_federation.sql
-- Description: Multi-Tenancy Architecture (Educational Centers SaaS) with Data Isolation and Center Federation/Linking

-- 1. Create Educational Centers Table
CREATE TABLE IF NOT EXISTS public.educational_centers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    phone_number TEXT,
    address TEXT,
    governorate TEXT DEFAULT 'Cairo',
    logo_url TEXT,
    owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    subscription_tier TEXT NOT NULL DEFAULT 'trial',
    subscription_status TEXT NOT NULL DEFAULT 'active',
    settings JSONB NOT NULL DEFAULT '{"allow_shared_teachers": true, "enable_sms": false, "currency": "EGP"}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_educational_centers_code ON public.educational_centers(code);
CREATE INDEX IF NOT EXISTS idx_educational_centers_owner ON public.educational_centers(owner_id);

-- 2. Add center_id column to branches
ALTER TABLE public.branches 
    ADD COLUMN IF NOT EXISTS center_id UUID REFERENCES public.educational_centers(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_branches_center_id ON public.branches(center_id);

-- 3. Add center_id column to profiles
ALTER TABLE public.profiles 
    ADD COLUMN IF NOT EXISTS center_id UUID REFERENCES public.educational_centers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_center_id ON public.profiles(center_id);

-- 4. Create Center Memberships Table (Supports teachers and students belonging to multiple centers)
CREATE TABLE IF NOT EXISTS public.center_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    center_id UUID NOT NULL REFERENCES public.educational_centers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'student',
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending')),
    is_primary BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (center_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_center_memberships_user ON public.center_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_center_memberships_center ON public.center_memberships(center_id);

-- 5. Create Center Partnerships Table (Linking different centers together)
CREATE TABLE IF NOT EXISTS public.center_partnerships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_center_id UUID NOT NULL REFERENCES public.educational_centers(id) ON DELETE CASCADE,
    partner_center_id UUID NOT NULL REFERENCES public.educational_centers(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'terminated')),
    shared_teachers_enabled BOOLEAN NOT NULL DEFAULT true,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_different_centers CHECK (requester_center_id <> partner_center_id),
    UNIQUE (requester_center_id, partner_center_id)
);

CREATE INDEX IF NOT EXISTS idx_center_partnerships_requester ON public.center_partnerships(requester_center_id);
CREATE INDEX IF NOT EXISTS idx_center_partnerships_partner ON public.center_partnerships(partner_center_id);

-- 6. Backfill existing legacy branches and profiles to a default seed center
DO $$
DECLARE
    default_center_id UUID := '00000000-0000-0000-0000-000000000001';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.educational_centers WHERE id = default_center_id) THEN
        INSERT INTO public.educational_centers (id, name, code, phone_number, governorate, subscription_tier, subscription_status)
        VALUES (
            default_center_id,
            'السنتر الرئيسي (Brivio)',
            'BRIVIO-MAIN',
            '+201000000000',
            'Cairo',
            'enterprise',
            'active'
        )
        ON CONFLICT (id) DO NOTHING;
    END IF;

    -- Update legacy branches
    UPDATE public.branches 
    SET center_id = default_center_id 
    WHERE center_id IS NULL;

    -- Update legacy profiles
    UPDATE public.profiles
    SET center_id = default_center_id
    WHERE center_id IS NULL;

    -- Create memberships for existing profiles
    INSERT INTO public.center_memberships (center_id, user_id, role, is_primary)
    SELECT p.center_id, p.id, p.role, true
    FROM public.profiles p
    WHERE p.center_id IS NOT NULL
    ON CONFLICT (center_id, user_id) DO NOTHING;
END $$;

-- 7. Security Helper: current_user_center_id()
CREATE OR REPLACE FUNCTION public.current_user_center_id()
RETURNS UUID AS $$
DECLARE
    c_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT center_id INTO c_id FROM public.profiles WHERE id = auth.uid();
    IF c_id IS NOT NULL THEN
        RETURN c_id;
    END IF;

    SELECT center_id INTO c_id 
    FROM public.center_memberships 
    WHERE user_id = auth.uid() AND is_primary = true 
    LIMIT 1;

    RETURN c_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 8. RPC: register_educational_center
-- Allows a center owner to sign up their center, creates primary branch, and provisions admin role.
DROP FUNCTION IF EXISTS public.register_educational_center(TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.register_educational_center(TEXT, TEXT, TEXT, TEXT, UUID);

CREATE OR REPLACE FUNCTION public.register_educational_center(
    p_center_name TEXT,
    p_admin_name TEXT,
    p_phone_number TEXT,
    p_governorate TEXT DEFAULT 'Cairo',
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    u_id UUID := COALESCE(auth.uid(), p_user_id);
    v_center_id UUID;
    v_center_code TEXT;
    v_branch_id UUID;
    v_clean_name TEXT := TRIM(p_center_name);
    v_clean_admin TEXT := TRIM(p_admin_name);
    v_clean_phone TEXT := TRIM(p_phone_number);
    v_clean_gov TEXT := TRIM(p_governorate);
BEGIN
    IF u_id IS NULL THEN
        RAISE EXCEPTION 'Must be authenticated or provide a valid user ID to register an educational center' USING ERRCODE = '42501';
    END IF;

    -- Verify that u_id actually exists in auth.users
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = u_id) THEN
        RAISE EXCEPTION 'User account not found' USING ERRCODE = '42501';
    END IF;

    IF v_clean_name = '' THEN
        RAISE EXCEPTION 'Center name is required';
    END IF;

    -- Generate a unique readable code for the center (e.g. CTR-XXXXXX)
    v_center_code := 'CTR-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 6));

    -- Create Center
    INSERT INTO public.educational_centers (
        name,
        code,
        phone_number,
        governorate,
        owner_id,
        subscription_tier,
        subscription_status
    ) VALUES (
        v_clean_name,
        v_center_code,
        v_clean_phone,
        v_clean_gov,
        u_id,
        'trial',
        'active'
    ) RETURNING id INTO v_center_id;

    -- Create Main Branch for this center
    INSERT INTO public.branches (
        name,
        code,
        phone_number,
        center_id,
        status
    ) VALUES (
        'الفرع الرئيسي',
        v_center_code || '-MAIN',
        v_clean_phone,
        v_center_id,
        'active'
    ) RETURNING id INTO v_branch_id;

    -- Update User Profile to be Admin of this Center
    UPDATE public.profiles
    SET 
        role = 'admin',
        center_id = v_center_id,
        branch_id = v_branch_id,
        full_name = CASE WHEN v_clean_admin <> '' THEN v_clean_admin ELSE full_name END,
        phone_number = CASE WHEN v_clean_phone <> '' THEN v_clean_phone ELSE phone_number END,
        updated_at = NOW()
    WHERE id = u_id;

    IF NOT FOUND THEN
        INSERT INTO public.profiles (
            id,
            email,
            full_name,
            role,
            phone_number,
            center_id,
            branch_id,
            account_status
        )
        SELECT 
            u_id,
            COALESCE(au.email, ''),
            CASE WHEN v_clean_admin <> '' THEN v_clean_admin ELSE 'Center Admin' END,
            'admin'::user_role,
            v_clean_phone,
            v_center_id,
            v_branch_id,
            'active'
        FROM auth.users au
        WHERE au.id = u_id
        ON CONFLICT (id) DO UPDATE SET
            role = 'admin',
            center_id = v_center_id,
            branch_id = v_branch_id,
            full_name = CASE WHEN v_clean_admin <> '' THEN v_clean_admin ELSE profiles.full_name END,
            phone_number = CASE WHEN v_clean_phone <> '' THEN v_clean_phone ELSE profiles.phone_number END,
            updated_at = NOW();
    END IF;

    -- Add Primary Membership
    INSERT INTO public.center_memberships (
        center_id,
        user_id,
        role,
        is_primary
    ) VALUES (
        v_center_id,
        u_id,
        'admin',
        true
    ) ON CONFLICT (center_id, user_id) DO UPDATE SET
        role = 'admin',
        is_primary = true;

    RETURN jsonb_build_object(
        'success', true,
        'center_id', v_center_id,
        'center_name', v_clean_name,
        'center_code', v_center_code,
        'branch_id', v_branch_id
    );
END;
$$;

-- 9. RPC: get_user_centers
-- Fetches all centers the current user belongs to (for Center Switcher)
CREATE OR REPLACE FUNCTION public.get_user_centers()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    u_id UUID := auth.uid();
    v_results JSONB;
BEGIN
    IF u_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'center_id', c.id,
            'center_name', c.name,
            'center_code', c.code,
            'logo_url', c.logo_url,
            'governorate', c.governorate,
            'role', m.role,
            'is_primary', (p.center_id = c.id),
            'subscription_status', c.subscription_status
        )
    ), '[]'::jsonb)
    INTO v_results
    FROM public.center_memberships m
    JOIN public.educational_centers c ON c.id = m.center_id
    JOIN public.profiles p ON p.id = m.user_id
    WHERE m.user_id = u_id AND m.status = 'active';

    RETURN v_results;
END;
$$;

-- 10. RPC: switch_active_center
CREATE OR REPLACE FUNCTION public.switch_active_center(p_center_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    u_id UUID := auth.uid();
    v_role user_role;
    v_branch_id UUID;
BEGIN
    IF u_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated';
    END IF;

    -- Verify membership
    SELECT role INTO v_role
    FROM public.center_memberships
    WHERE user_id = u_id AND center_id = p_center_id AND status = 'active';

    IF v_role IS NULL THEN
        RAISE EXCEPTION 'You do not have active membership in this center';
    END IF;

    -- Pick first active branch of that center
    SELECT id INTO v_branch_id
    FROM public.branches
    WHERE center_id = p_center_id AND status = 'active'
    ORDER BY created_at ASC
    LIMIT 1;

    -- Update profile
    UPDATE public.profiles
    SET 
        center_id = p_center_id,
        branch_id = v_branch_id,
        role = v_role,
        updated_at = NOW()
    WHERE id = u_id;

    RETURN jsonb_build_object(
        'success', true,
        'center_id', p_center_id,
        'role', v_role,
        'branch_id', v_branch_id
    );
END;
$$;

-- 11. RPC: link_centers_by_code
-- Allows center admin to initiate a partnership with another center using their code
CREATE OR REPLACE FUNCTION public.link_centers_by_code(
    p_target_center_code TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    u_id UUID := auth.uid();
    v_my_center_id UUID;
    v_target_center_id UUID;
    v_partnership_id UUID;
BEGIN
    v_my_center_id := public.current_user_center_id();
    IF v_my_center_id IS NULL OR NOT public.is_admin_or_super() THEN
        RAISE EXCEPTION 'Only center admins can link with other centers';
    END IF;

    SELECT id INTO v_target_center_id
    FROM public.educational_centers
    WHERE code = UPPER(TRIM(p_target_center_code));

    IF v_target_center_id IS NULL THEN
        RAISE EXCEPTION 'Center code not found';
    END IF;

    IF v_my_center_id = v_target_center_id THEN
        RAISE EXCEPTION 'Cannot link a center with itself';
    END IF;

    INSERT INTO public.center_partnerships (
        requester_center_id,
        partner_center_id,
        status,
        notes
    ) VALUES (
        v_my_center_id,
        v_target_center_id,
        'pending',
        p_notes
    )
    ON CONFLICT (requester_center_id, partner_center_id) 
    DO UPDATE SET 
        status = 'pending',
        notes = EXCLUDED.notes,
        updated_at = NOW()
    RETURNING id INTO v_partnership_id;

    RETURN jsonb_build_object(
        'success', true,
        'partnership_id', v_partnership_id,
        'status', 'pending'
    );
END;
$$;

-- 12. Update get_current_user_bootstrap to include center details
CREATE OR REPLACE FUNCTION public.get_current_user_bootstrap()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  u_id UUID := auth.uid();
  user_prof RECORD;
  eff_perms TEXT[];
  s_id UUID;
  p_id UUID;
  t_id UUID;
  center_rec RECORD;
  user_centers JSONB;
BEGIN
  IF u_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated caller' USING ERRCODE = '42501';
  END IF;

  SELECT id, email, full_name, avatar_url, phone_number, role, branch_id, center_id,
         status, created_at, updated_at
  INTO user_prof
  FROM public.profiles
  WHERE id = u_id;

  IF user_prof IS NULL THEN
    RAISE EXCEPTION 'Profile missing for authenticated user' USING ERRCODE = 'P0002';
  END IF;

  -- Load center info if assigned
  IF user_prof.center_id IS NOT NULL THEN
    SELECT id, name, code, governorate, subscription_status
    INTO center_rec
    FROM public.educational_centers
    WHERE id = user_prof.center_id;
  END IF;

  eff_perms := public.get_user_effective_permissions(u_id);

  SELECT id INTO s_id FROM public.students WHERE profile_id = u_id LIMIT 1;
  SELECT id INTO p_id FROM public.parents WHERE profile_id = u_id LIMIT 1;
  SELECT id INTO t_id FROM public.teachers WHERE profile_id = u_id LIMIT 1;

  -- Fetch user available centers
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'center_id', c.id,
      'center_name', c.name,
      'center_code', c.code,
      'role', m.role,
      'is_primary', (user_prof.center_id = c.id)
    )
  ), '[]'::jsonb)
  INTO user_centers
  FROM public.center_memberships m
  JOIN public.educational_centers c ON c.id = m.center_id
  WHERE m.user_id = u_id AND m.status = 'active';

  RETURN jsonb_build_object(
    'profile', jsonb_build_object(
      'id', user_prof.id,
      'email', user_prof.email,
      'full_name', user_prof.full_name,
      'avatar_url', user_prof.avatar_url,
      'phone_number', user_prof.phone_number,
      'role', user_prof.role,
      'branch_id', user_prof.branch_id,
      'center_id', user_prof.center_id,
      'status', user_prof.status,
      'created_at', user_prof.created_at,
      'updated_at', user_prof.updated_at
    ),
    'canonical_role', user_prof.role,
    'primary_branch_id', user_prof.branch_id,
    'active_center', CASE WHEN center_rec.id IS NOT NULL THEN jsonb_build_object(
      'id', center_rec.id,
      'name', center_rec.name,
      'code', center_rec.code,
      'governorate', center_rec.governorate,
      'subscription_status', center_rec.subscription_status
    ) ELSE NULL END,
    'available_centers', user_centers,
    'account_status', user_prof.status,
    'effective_permissions', to_jsonb(eff_perms),
    'domain_identity', jsonb_build_object(
      'student_id', s_id,
      'parent_id', p_id,
      'teacher_id', t_id
    )
  );
END;
$$;

-- 13. Enable RLS and setup policies on educational_centers
ALTER TABLE public.educational_centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.center_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.center_partnerships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can view centers they are a member of or by public code" ON public.educational_centers;
CREATE POLICY "Anyone authenticated can view centers they are a member of or by public code"
    ON public.educational_centers FOR SELECT
    TO authenticated
    USING (
        id = public.current_user_center_id() OR
        EXISTS (SELECT 1 FROM public.center_memberships WHERE center_id = educational_centers.id AND user_id = auth.uid()) OR
        public.is_super_admin()
    );

DROP POLICY IF EXISTS "Center owner or admin can update their center" ON public.educational_centers;
CREATE POLICY "Center owner or admin can update their center"
    ON public.educational_centers FOR UPDATE
    TO authenticated
    USING (owner_id = auth.uid() OR (id = public.current_user_center_id() AND public.is_admin_or_super()))
    WITH CHECK (owner_id = auth.uid() OR (id = public.current_user_center_id() AND public.is_admin_or_super()));

DROP POLICY IF EXISTS "Users can view their own center memberships" ON public.center_memberships;
CREATE POLICY "Users can view their own center memberships"
    ON public.center_memberships FOR SELECT
    TO authenticated
    USING (user_id = auth.uid() OR (center_id = public.current_user_center_id() AND public.is_admin_or_super()));

DROP POLICY IF EXISTS "Admins can manage memberships for their center" ON public.center_memberships;
CREATE POLICY "Admins can manage memberships for their center"
    ON public.center_memberships FOR ALL
    TO authenticated
    USING (center_id = public.current_user_center_id() AND public.is_admin_or_super())
    WITH CHECK (center_id = public.current_user_center_id() AND public.is_admin_or_super());

DROP POLICY IF EXISTS "Center partnerships viewable by participants" ON public.center_partnerships;
CREATE POLICY "Center partnerships viewable by participants"
    ON public.center_partnerships FOR SELECT
    TO authenticated
    USING (
        requester_center_id = public.current_user_center_id() OR
        partner_center_id = public.current_user_center_id() OR
        public.is_super_admin()
    );

DROP POLICY IF EXISTS "Center partnerships manageable by center admins" ON public.center_partnerships;
CREATE POLICY "Center partnerships manageable by center admins"
    ON public.center_partnerships FOR ALL
    TO authenticated
    USING (
        (requester_center_id = public.current_user_center_id() AND public.is_admin_or_super()) OR
        public.is_super_admin()
    )
    WITH CHECK (
        (requester_center_id = public.current_user_center_id() AND public.is_admin_or_super()) OR
        public.is_super_admin()
    );

-- Grants
GRANT EXECUTE ON FUNCTION public.register_educational_center(TEXT, TEXT, TEXT, TEXT, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_centers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.switch_active_center(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.link_centers_by_code(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_center_id() TO authenticated;

NOTIFY pgrst, 'reload schema';
