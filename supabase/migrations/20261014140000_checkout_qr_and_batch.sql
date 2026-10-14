-- Migration: Add validate_checkout_qr and batch checkout support
CREATE OR REPLACE FUNCTION public.validate_checkout_qr(
  p_token TEXT,
  p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
  v_qr RECORD;
  v_record_id UUID;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_qr
  FROM public.attendance_qr_sessions
  WHERE token = trim(COALESCE(p_token, ''))
    AND status = 'active'
    AND expires_at > NOW()
  LIMIT 1;

  IF v_qr.id IS NULL THEN
    RAISE EXCEPTION 'Attendance QR has expired or is invalid' USING ERRCODE = '22023';
  END IF;

  UPDATE public.attendance_records
  SET check_out_at = NOW(), updated_at = NOW()
  WHERE class_session_id = v_qr.class_session_id
    AND student_id = v_student_id
    AND attendance_status IN ('present', 'late')
  RETURNING id INTO v_record_id;

  IF v_record_id IS NULL THEN
    RAISE EXCEPTION 'No active check-in record found for this session' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'attendance_record_id', v_record_id,
    'class_session_id', v_qr.class_session_id,
    'check_out_at', NOW()
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.validate_checkout_qr(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_checkout_qr(TEXT, TEXT) TO authenticated;

-- Function: Batch mark checkout for teacher
CREATE OR REPLACE FUNCTION public.batch_mark_checkout(
  p_class_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE public.attendance_records
  SET check_out_at = NOW(), updated_at = NOW()
  WHERE class_session_id = p_class_session_id
    AND attendance_status IN ('present', 'late')
    AND check_out_at IS NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'class_session_id', p_class_session_id,
    'checked_out_count', v_count
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.batch_mark_checkout(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.batch_mark_checkout(UUID) TO authenticated;
