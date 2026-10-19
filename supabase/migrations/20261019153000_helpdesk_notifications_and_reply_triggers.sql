-- Migration: 20261019153000_helpdesk_notifications_and_reply_triggers.sql
-- Description: Automatic in-app and push notifications for helpdesk tickets, replies, and status changes.
-- Also upgrades add_ticket_reply and update_support_ticket_status RPCs for seamless delivery.

-- 1. Upgrade add_ticket_reply RPC to ensure auto-assignment and robust permissions
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

  -- Verify authorization:
  -- Allowed if:
  -- 1) Ticket creator
  -- 2) Admin / Staff
  -- 3) Assigned teacher
  -- 4) Teacher assigned to ticket group
  -- 5) Any teacher teaching the student in any group
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

  -- Insert reply
  INSERT INTO public.ticket_replies (ticket_id, user_id, message, created_at)
  VALUES (p_ticket_id, auth.uid(), trim(p_message), NOW())
  RETURNING * INTO inserted_reply;

  -- If ticket was open, automatically advance to in_progress
  -- If teacher replied and assigned_teacher_id is null, auto-assign
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

-- 2. Upgrade update_support_ticket_status RPC
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

  -- Allowed if:
  -- 1) Ticket creator (can resolve or close their own ticket)
  -- 2) Admin / Staff
  -- 3) Assigned teacher
  -- 4) Teacher assigned to ticket group
  -- 5) Teacher who teaches this student
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

-- 3. Trigger Function: Notify on new ticket created
CREATE OR REPLACE FUNCTION public.trigger_notify_on_support_ticket_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- A. Notify assigned teacher if explicitly set
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

  -- B. Notify group teachers if group is specified and no assigned teacher yet
  ELSIF NEW.group_id IS NOT NULL THEN
    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
    SELECT DISTINCT t.profile_id,
           'تذكرة دعم فني جديدة 🎫',
           'تم فتح تذكرة جديدة مرتبطة بمجموعتك: "' || NEW.subject || '"',
           'ticket',
           NEW.id
    FROM public.group_teachers gt
    JOIN public.teachers t ON t.id = gt.teacher_id
    WHERE gt.group_id = NEW.group_id
      AND t.profile_id IS NOT NULL
      AND t.profile_id <> NEW.user_id;
  END IF;

  -- C. Notify center administrators and staff
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

-- 4. Trigger Function: Notify on new ticket reply
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

  -- Case 1: Replier is NOT the ticket creator (Teacher / Admin replied)
  IF NEW.user_id <> v_ticket.user_id THEN
    -- Notify ticket creator (Student or Parent)
    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
    VALUES (
      v_ticket.user_id,
      'رد جديد على تذكرتك 💬',
      'وصلك رد جديد على التذكرة "' || v_ticket.subject || '": ' || v_short_msg,
      'ticket',
      v_ticket.id
    );

    -- If the ticket creator is a student, also notify their parents
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

  -- Case 2: Replier IS the ticket creator (Student or Parent replied back)
  ELSE
    -- Notify assigned teacher
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

    -- Or group teachers if unassigned
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

    -- Also notify Admins/Staff
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

-- 5. Trigger Function: Notify on ticket status updated
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

    -- Notify ticket creator (if the change was not made by the creator themselves)
    IF v_changer_id IS NULL OR v_changer_id <> NEW.user_id THEN
      INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
      VALUES (
        NEW.user_id,
        'تحديث حالة تذكرة الدعم 🔄',
        'تم تغيير حالة تذكرتك "' || NEW.subject || '" إلى (' || v_status_ar || ').',
        'ticket',
        NEW.id
      );

      -- If creator is a student, also notify their parents
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

-- 6. Grants & reload
GRANT EXECUTE ON FUNCTION public.add_ticket_reply(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_support_ticket_status(UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
