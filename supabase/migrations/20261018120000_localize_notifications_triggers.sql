-- Migration: 20261018120000_localize_notifications_triggers.sql
-- Description: Update database triggers so that system-generated notifications are created in Arabic natively,
-- with dynamic client bidirectional localization for English users.

-- 1. Lesson Published Trigger
CREATE OR REPLACE FUNCTION public.trigger_notify_on_lesson_published()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status != 'published')) THEN
        INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
        SELECT DISTINCT s.profile_id,
               'تم نشر درس جديد',
               'تمت إضافة درس جديد "' || NEW.title || '" إلى مقررك الدراسي.',
               'lesson',
               NEW.id
        FROM public.units u
        JOIN public.groups g ON g.subject_id = u.subject_id
        JOIN public.enrollments e ON e.group_id = g.id
        JOIN public.students s ON s.id = e.student_id
        WHERE u.id = NEW.unit_id 
          AND e.status = 'active' 
          AND g.status = 'active' 
          AND s.profile_id IS NOT NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Assessment Published Trigger (Exams & Homework)
CREATE OR REPLACE FUNCTION public.trigger_notify_on_assessment_published()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status != 'published')) THEN
        IF NEW.group_id IS NOT NULL THEN
            INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
            SELECT DISTINCT s.profile_id,
                   CASE WHEN TG_TABLE_NAME = 'exams' THEN 'تم نشر اختبار جديد' ELSE 'تم نشر واجب جديد' END,
                   CASE WHEN TG_TABLE_NAME = 'exams' 
                        THEN 'تمت جدولة اختبار جديد "' || NEW.title || '".' 
                        ELSE 'تم تعيين واجب منزلي جديد "' || NEW.title || '".' 
                   END,
                   CASE WHEN TG_TABLE_NAME = 'exams' THEN 'exam' ELSE 'homework' END,
                   NEW.id
            FROM public.enrollments e
            JOIN public.students s ON s.id = e.student_id
            WHERE e.group_id = NEW.group_id 
              AND e.status = 'active' 
              AND s.profile_id IS NOT NULL;
        ELSE
            -- Fallback: notify all active groups in subject
            INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
            SELECT DISTINCT s.profile_id,
                   CASE WHEN TG_TABLE_NAME = 'exams' THEN 'تم نشر اختبار جديد' ELSE 'تم نشر واجب جديد' END,
                   CASE WHEN TG_TABLE_NAME = 'exams' 
                        THEN 'تمت جدولة اختبار جديد "' || NEW.title || '".' 
                        ELSE 'تم تعيين واجب منزلي جديد "' || NEW.title || '".' 
                   END,
                   CASE WHEN TG_TABLE_NAME = 'exams' THEN 'exam' ELSE 'homework' END,
                   NEW.id
            FROM public.groups g
            JOIN public.enrollments e ON e.group_id = g.id
            JOIN public.students s ON s.id = e.student_id
            WHERE g.subject_id = NEW.subject_id 
              AND e.status = 'active' 
              AND g.status = 'active'
              AND s.profile_id IS NOT NULL;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Grading Notifications (Submissions & Exam Attempts)
CREATE OR REPLACE FUNCTION public.trigger_notify_on_submission_graded()
RETURNS TRIGGER AS $$
DECLARE
    v_profile_id UUID;
    v_title TEXT;
BEGIN
    IF NEW.status = 'graded' AND (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status != 'graded')) THEN
        SELECT profile_id INTO v_profile_id FROM public.students WHERE id = NEW.student_id;
        
        IF v_profile_id IS NOT NULL THEN
            IF TG_TABLE_NAME = 'exam_attempts' THEN
                SELECT title INTO v_title FROM public.exams WHERE id = NEW.exam_id;
                IF v_title IS NOT NULL THEN
                    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
                    VALUES (
                        v_profile_id, 
                        'تم رصد درجات الاختبار', 
                        'تم رصد نتيجة محاولتك في اختبار "' || v_title || '". الدرجة: ' || COALESCE(NEW.score::text, 'مكتمل'), 
                        'grade', 
                        NEW.id
                    );
                END IF;
            ELSIF TG_TABLE_NAME = 'homework_submissions' THEN
                SELECT title INTO v_title FROM public.homework WHERE id = NEW.homework_id;
                IF v_title IS NOT NULL THEN
                    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
                    VALUES (
                        v_profile_id, 
                        'تم تصحيح الواجب', 
                        'تم تصحيح تسليمك للواجب "' || v_title || '". الدرجة: ' || COALESCE(NEW.score::text, 'مكتمل'), 
                        'grade', 
                        NEW.id
                    );
                END IF;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Enrollment Confirmation Trigger
CREATE OR REPLACE FUNCTION public.notify_enrollment_schedule_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_name TEXT;
BEGIN
  IF TG_OP = 'INSERT'
     OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'active') THEN
    SELECT name INTO v_group_name
    FROM public.groups
    WHERE id = NEW.group_id;

    PERFORM public.notify_student_and_parents(
      NEW.student_id,
      'تم تأكيد الانضمام للمجموعة',
      'تم تفعيل تسجيلك في مجموعة ' || COALESCE(v_group_name, 'المحددة') || ' بنجاح.',
      'enrollment',
      NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$;

-- 5. Schedule Event Trigger
CREATE OR REPLACE FUNCTION public.notify_group_schedule_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_id UUID;
  v_group_name TEXT;
  v_title TEXT;
  v_message TEXT;
  v_reference_id UUID;
  enr RECORD;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_group_id := OLD.group_id;
    v_reference_id := OLD.id;
    v_title := 'إلغاء موعد للمجموعة';
  ELSE
    v_group_id := NEW.group_id;
    v_reference_id := NEW.id;
    v_title := CASE WHEN TG_OP = 'INSERT' THEN 'جدول مواعيد جديد للمجموعة' ELSE 'تعديل جدول المجموعة' END;
  END IF;

  SELECT name INTO v_group_name
  FROM public.groups
  WHERE id = v_group_id;

  v_message := 'تم تحديث جدول مواعيد ' || COALESCE(v_group_name, 'مجموعتك') || '. يُرجى مراجعة جدول الحصص.';

  FOR enr IN
    SELECT student_id
    FROM public.enrollments
    WHERE group_id = v_group_id
      AND status = 'active'
  LOOP
    PERFORM public.notify_student_and_parents(
      enr.student_id,
      v_title,
      v_message,
      'schedule',
      v_reference_id
    );
  END LOOP;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

-- 6. Parent Exam Published Trigger
CREATE OR REPLACE FUNCTION public.notify_parents_on_exam_published()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status <> 'published' THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
  SELECT DISTINCT
    p.profile_id,
    'تم نشر اختبار جديد',
    'اختبار جديد "' || NEW.title || '" متاح لابنك/ابنتك.',
    'exam',
    NEW.id
  FROM public.enrollments e
  JOIN public.parent_students ps ON ps.student_id = e.student_id
  JOIN public.parents p ON p.id = ps.parent_id
  WHERE e.group_id = NEW.group_id
    AND e.status = 'active'
    AND p.profile_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.app_notifications n
      WHERE n.user_id = p.profile_id
        AND n.type = 'exam'
        AND n.reference_id = NEW.id
        AND (n.title = 'New exam published' OR n.title = 'تم نشر اختبار جديد')
    );

  RETURN NEW;
END;
$$;

-- 7. Parent Exam Graded Trigger
CREATE OR REPLACE FUNCTION public.notify_parents_on_exam_graded()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title TEXT;
BEGIN
  IF NEW.status <> 'graded' THEN
    RETURN NEW;
  END IF;

  SELECT title INTO v_title FROM public.exams WHERE id = NEW.exam_id;

  INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
  SELECT DISTINCT
    p.profile_id,
    'تم رصد درجات الاختبار',
    'تم تصحيح اختبار ابنك/ابنتك "' || COALESCE(v_title, 'الاختبار') || '". الدرجة: ' || COALESCE(NEW.score::TEXT, 'مكتمل'),
    'grade',
    NEW.exam_id
  FROM public.parent_students ps
  JOIN public.parents p ON p.id = ps.parent_id
  WHERE ps.student_id = NEW.student_id
    AND p.profile_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.app_notifications n
      WHERE n.user_id = p.profile_id
        AND n.type = 'grade'
        AND n.reference_id = NEW.exam_id
        AND (n.title = 'Exam graded' OR n.title = 'تم رصد درجات الاختبار')
    );

  RETURN NEW;
END;
$$;

-- 8. Translate existing historical notifications in database
UPDATE public.app_notifications
SET title = 'تم نشر درس جديد'
WHERE title ILIKE '%New Lesson Published%';

UPDATE public.app_notifications
SET title = 'تم نشر اختبار جديد'
WHERE title ILIKE '%New Exam Published%' OR title ILIKE '%New exam published%';

UPDATE public.app_notifications
SET title = 'تم نشر واجب جديد'
WHERE title ILIKE '%New Homework Published%';

UPDATE public.app_notifications
SET title = 'تم رصد درجات الاختبار'
WHERE title ILIKE '%Exam Graded%' OR title ILIKE '%Exam graded%';

UPDATE public.app_notifications
SET title = 'تم تصحيح الواجب'
WHERE title ILIKE '%Homework Graded%';

UPDATE public.app_notifications
SET title = 'تم تأكيد الانضمام للمجموعة'
WHERE title ILIKE '%Group enrollment confirmed%';

UPDATE public.app_notifications
SET title = 'تعديل جدول المجموعة'
WHERE title ILIKE '%Group schedule changed%' OR title ILIKE '%New group schedule%';

NOTIFY pgrst, 'reload schema';
