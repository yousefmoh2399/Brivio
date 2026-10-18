import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/core/localization/notification_localizer.dart';

void main() {
  group('NotificationLocalizer Unit Tests', () {
    test('localizes English titles to Arabic when isArabic is true', () {
      expect(
        NotificationLocalizer.localizeTitle('New Lesson Published', isArabic: true),
        equals('تم نشر درس جديد'),
      );
      expect(
        NotificationLocalizer.localizeTitle('New Exam Published', isArabic: true),
        equals('تم نشر اختبار جديد'),
      );
      expect(
        NotificationLocalizer.localizeTitle('Exam Graded', isArabic: true),
        equals('تم رصد درجات الاختبار'),
      );
      expect(
        NotificationLocalizer.localizeTitle('Homework Graded', isArabic: true),
        equals('تم تصحيح الواجب'),
      );
      expect(
        NotificationLocalizer.localizeTitle('Group enrollment confirmed', isArabic: true),
        equals('تم تأكيد الانضمام للمجموعة'),
      );
    });

    test('localizes Arabic titles to English when isArabic is false', () {
      expect(
        NotificationLocalizer.localizeTitle('تم نشر درس جديد', isArabic: false),
        equals('New Lesson Published'),
      );
      expect(
        NotificationLocalizer.localizeTitle('تم نشر اختبار جديد', isArabic: false),
        equals('New Exam Published'),
      );
      expect(
        NotificationLocalizer.localizeTitle('تم رصد درجات الاختبار', isArabic: false),
        equals('Exam Graded'),
      );
      expect(
        NotificationLocalizer.localizeTitle('تم تأكيد الانضمام للمجموعة', isArabic: false),
        equals('Group Enrollment Confirmed'),
      );
    });

    test('localizes parametric messages to Arabic correctly', () {
      expect(
        NotificationLocalizer.localizeMessage(
          'A new lesson "Calculus" has been added to your course.',
          isArabic: true,
        ),
        equals('تمت إضافة درس جديد "Calculus" إلى مقررك الدراسي.'),
      );

      expect(
        NotificationLocalizer.localizeMessage(
          'A new exam "Midterm 2026" has been scheduled.',
          isArabic: true,
        ),
        equals('تمت جدولة اختبار جديد "Midterm 2026".'),
      );

      expect(
        NotificationLocalizer.localizeMessage(
          'Your attempt for "Algebra Quiz" has been graded. Score: 95/100',
          isArabic: true,
        ),
        equals('تم رصد نتيجة محاولتك في اختبار "Algebra Quiz". الدرجة: 95/100'),
      );

      expect(
        NotificationLocalizer.localizeMessage(
          'Enrollment in Physics Group A is now active.',
          isArabic: true,
        ),
        equals('تم تفعيل تسجيلك في Physics Group A بنجاح.'),
      );
    });

    test('localizes parametric messages to English correctly', () {
      expect(
        NotificationLocalizer.localizeMessage(
          'تمت إضافة درس جديد "التفاضل والتكامل" إلى مقررك الدراسي.',
          isArabic: false,
        ),
        equals('A new lesson "التفاضل والتكامل" has been added to your course.'),
      );

      expect(
        NotificationLocalizer.localizeMessage(
          'تمت جدولة اختبار جديد "اختبار نصف العام".',
          isArabic: false,
        ),
        equals('A new exam "اختبار نصف العام" has been scheduled.'),
      );

      expect(
        NotificationLocalizer.localizeMessage(
          'تم رصد نتيجة محاولتك في اختبار "كيمياء عضوية". الدرجة: 88/100',
          isArabic: false,
        ),
        equals('Your attempt for "كيمياء عضوية" has been graded. Score: 88/100'),
      );
    });

    test('localizes notification category labels', () {
      expect(NotificationLocalizer.localizeCategory('academic', isArabic: true), equals('أكاديمي'));
      expect(NotificationLocalizer.localizeCategory('financial', isArabic: true), equals('مالي كاش'));
      expect(NotificationLocalizer.localizeCategory('general', isArabic: true), equals('تنبيه سنتر'));

      expect(NotificationLocalizer.localizeCategory('أكاديمي', isArabic: false), equals('Academic'));
      expect(NotificationLocalizer.localizeCategory('مالي كاش', isArabic: false), equals('Financial'));
      expect(NotificationLocalizer.localizeCategory('تنبيه سنتر', isArabic: false), equals('Center Alert'));
    });
  });
}
