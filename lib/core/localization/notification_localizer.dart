
/// Comprehensive bidirectional localizer for push notifications and notification inbox.
/// Converts system and academic notifications between Arabic and English dynamically
/// based on the user's selected application language.
class NotificationLocalizer {
  NotificationLocalizer._();

  static bool _hasArabic(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(text);
  }

  // ── Exact Title Mappings ──────────────────────────────────────────────────
  static const Map<String, String> _enToArTitles = {
    'new lesson published': 'تم نشر درس جديد',
    'new lesson': 'درس جديد',
    'new exam published': 'تم نشر اختبار جديد',
    'new exam': 'اختبار جديد',
    'new homework published': 'تم نشر واجب جديد',
    'new homework': 'واجب منزلي جديد',
    'exam graded': 'تم رصد درجات الاختبار',
    'homework graded': 'تم تصحيح الواجب',
    'group enrollment confirmed': 'تم تأكيد الانضمام للمجموعة',
    'enrollment confirmed': 'تم تأكيد التسجيل',
    'new group schedule': 'جدول مواعيد جديد للمجموعة',
    'group schedule changed': 'تعديل جدول المجموعة',
    'group schedule removed': 'إلغاء موعد للمجموعة',
    'student checked in': 'تسجيل حضور الطالب',
    'attendance recorded': 'تم تسجيل الحضور',
    'student absent': 'تنبيه غياب طالب',
    'student marked absent': 'تسجيل غياب الطالب',
    'payment received': 'تم استلام الدفعة',
    'payment confirmed': 'تم تأكيد السداد',
    'invoice generated': 'تم إصدار فاتورة جديدة',
    'receipt created': 'تم إصدار إيصال سداد',
    'subscription renewed': 'تم تجديد الاشتراك بنجاح',
    'system broadcast': 'إشعار عام من السنتر',
    'center notice': 'تنبيه من إدارة السنتر',
    'test alert': 'تنبيه تجريبي من منصة بريفيو 🔔',
    'test notification': 'تنبيه تجريبي من منصة بريفيو 🔔',
    'academy notifications': 'إشعارات الأكاديمية والسنتر',
  };

  static const Map<String, String> _arToEnTitles = {
    'تم نشر درس جديد': 'New Lesson Published',
    'درس جديد': 'New Lesson',
    'تم نشر اختبار جديد': 'New Exam Published',
    'اختبار جديد': 'New Exam',
    'تم نشر واجب جديد': 'New Homework Published',
    'واجب منزلي جديد': 'New Homework',
    'واجب جديد': 'New Homework',
    'تم رصد درجات الاختبار': 'Exam Graded',
    'تم تصحيح الاختبار': 'Exam Graded',
    'تم تصحيح الواجب': 'Homework Graded',
    'تم رصد نتيجة الواجب': 'Homework Graded',
    'تم تأكيد الانضمام للمجموعة': 'Group Enrollment Confirmed',
    'تم تأكيد التسجيل': 'Enrollment Confirmed',
    'جدول مواعيد جديد للمجموعة': 'New Group Schedule',
    'جدول مواعيد جديد': 'New Schedule',
    'تعديل جدول المجموعة': 'Group Schedule Changed',
    'إلغاء موعد للمجموعة': 'Group Schedule Removed',
    'تسجيل حضور الطالب': 'Student Attendance Recorded',
    'تم تسجيل الحضور': 'Attendance Recorded',
    'تنبيه غياب طالب': 'Student Absence Alert',
    'غياب طالب': 'Student Absence Alert',
    'تسجيل غياب الطالب': 'Student Absence Alert',
    'تم استلام الدفعة': 'Payment Received',
    'تم تأكيد السداد': 'Payment Confirmed',
    'تم إصدار فاتورة جديدة': 'New Invoice Generated',
    'تم إصدار إيصال سداد': 'Payment Receipt Issued',
    'تم تجديد الاشتراك بنجاح': 'Subscription Renewed',
    'إشعار عام من السنتر': 'Center Announcement',
    'تنبيه من إدارة السنتر': 'Center Administration Alert',
    'إشعار من الإدارة': 'Management Notice',
    'تنبيه تجريبي من منصة بريفيو 🔔': 'Test Alert from Brivio Platform 🔔',
  };

  /// Localizes a notification title according to [isArabic].
  static String localizeTitle(String? title, {required bool isArabic}) {
    if (title == null || title.trim().isEmpty) {
      return isArabic ? 'إشعار جديد' : 'New Notification';
    }

    final trimmed = title.trim();

    if (isArabic) {
      // If already Arabic, keep it
      if (_hasArabic(trimmed)) return trimmed;

      final lower = trimmed.toLowerCase();
      if (_enToArTitles.containsKey(lower)) {
        return _enToArTitles[lower]!;
      }

      // Prefix match (e.g. "Absence Alert: Group 1")
      if (lower.startsWith('absence alert:')) {
        final rest = trimmed.substring('absence alert:'.length).trim();
        return 'تنبيه غياب: $rest';
      }
      if (lower.startsWith('new exam:')) {
        final rest = trimmed.substring('new exam:'.length).trim();
        return 'اختبار جديد: $rest';
      }
      if (lower.startsWith('new lesson:')) {
        final rest = trimmed.substring('new lesson:'.length).trim();
        return 'درس جديد: $rest';
      }

      return trimmed;
    } else {
      // English requested
      if (!_hasArabic(trimmed)) return trimmed;

      if (_arToEnTitles.containsKey(trimmed)) {
        return _arToEnTitles[trimmed]!;
      }

      for (final entry in _arToEnTitles.entries) {
        if (trimmed == entry.key) return entry.value;
      }

      if (trimmed.startsWith('غياب طالب:') || trimmed.startsWith('تنبيه غياب طالب:')) {
        final colonIdx = trimmed.indexOf(':');
        final rest = colonIdx != -1 ? trimmed.substring(colonIdx + 1).trim() : '';
        return 'Student Absence Alert: $rest';
      }
      if (trimmed.startsWith('اختبار جديد:')) {
        final rest = trimmed.substring('اختبار جديد:'.length).trim();
        return 'New Exam: $rest';
      }
      if (trimmed.startsWith('درس جديد:')) {
        final rest = trimmed.substring('درس جديد:'.length).trim();
        return 'New Lesson: $rest';
      }

      return trimmed;
    }
  }

  /// Localizes a notification message / body according to [isArabic].
  static String localizeMessage(String? message, {required bool isArabic}) {
    if (message == null || message.trim().isEmpty) return '';

    final trimmed = message.trim();

    if (isArabic) {
      if (_hasArabic(trimmed)) return trimmed;

      // 1. Lessons
      var match = RegExp(r'A new lesson "(.*?)" has been added to your course\.?', caseSensitive: false).firstMatch(trimmed);
      if (match != null) {
        return 'تمت إضافة درس جديد "${match.group(1)}" إلى مقررك الدراسي.';
      }

      // 2. Exams
      match = RegExp(r'A new exam "(.*?)" has been scheduled\.?', caseSensitive: false).firstMatch(trimmed);
      if (match != null) {
        return 'تمت جدولة اختبار جديد "${match.group(1)}".';
      }
      match = RegExp(r'A new exam "(.*?)" is available for your child\.?', caseSensitive: false).firstMatch(trimmed);
      if (match != null) {
        return 'اختبار جديد "${match.group(1)}" متاح لابنك/ابنتك.';
      }

      // 3. Homework
      match = RegExp(r'New homework "(.*?)" has been assigned\.?', caseSensitive: false).firstMatch(trimmed);
      if (match != null) {
        return 'تم تعيين واجب منزلي جديد "${match.group(1)}".';
      }

      // 4. Grading
      match = RegExp(r'Your attempt for "(.*?)" has been graded\.\s*Score:\s*(.+)', caseSensitive: false).firstMatch(trimmed);
      if (match != null) {
        final score = match.group(2)!.trim();
        final displayScore = score.toUpperCase() == 'N/A' ? 'مكتمل' : score;
        return 'تم رصد نتيجة محاولتك في اختبار "${match.group(1)}". الدرجة: $displayScore';
      }

      match = RegExp(r'Your child exam "(.*?)" has been graded\.\s*Score:\s*(.+)', caseSensitive: false).firstMatch(trimmed);
      if (match != null) {
        final score = match.group(2)!.trim();
        final displayScore = score.toUpperCase() == 'N/A' ? 'مكتمل' : score;
        return 'تم تصحيح اختبار ابنك/ابنتك "${match.group(1)}". الدرجة: $displayScore';
      }

      match = RegExp(r'Your submission for "(.*?)" has been graded\.\s*Score:\s*(.+)', caseSensitive: false).firstMatch(trimmed);
      if (match != null) {
        final score = match.group(2)!.trim();
        final displayScore = score.toUpperCase() == 'N/A' ? 'مكتمل' : score;
        return 'تم تصحيح تسليمك للواجب "${match.group(1)}". الدرجة: $displayScore';
      }

      // 5. Enrollment
      match = RegExp(r'Enrollment in (.*?) is now active\.?', caseSensitive: false).firstMatch(trimmed);
      if (match != null) {
        return 'تم تفعيل تسجيلك في ${match.group(1)} بنجاح.';
      }

      // 6. Schedule
      match = RegExp(r'(.*?) schedule was updated\.\s*Please check your timetable\.?', caseSensitive: false).firstMatch(trimmed);
      if (match != null) {
        return 'تم تحديث جدول مواعيد ${match.group(1)}. يُرجى مراجعة جدول الحصص.';
      }

      // 7. Test notification
      if (trimmed.toLowerCase().contains('push notification system is working properly') ||
          trimmed.toLowerCase().contains('push notifications are working properly')) {
        return 'نظام الإشعارات الفورية يعمل بكفاءة على جهازك ومستعد لاستقبال التنبيهات.';
      }

      return trimmed;
    } else {
      // English requested
      if (!_hasArabic(trimmed)) return trimmed;

      // 1. Lessons
      var match = RegExp(r'تمت إضافة درس جديد "(.*?)" إلى مقررك الدراسي\.?').firstMatch(trimmed);
      if (match != null) {
        return 'A new lesson "${match.group(1)}" has been added to your course.';
      }

      // 2. Exams
      match = RegExp(r'تمت جدولة اختبار جديد "(.*?)"\.?').firstMatch(trimmed);
      if (match != null) {
        return 'A new exam "${match.group(1)}" has been scheduled.';
      }
      match = RegExp(r'اختبار جديد "(.*?)" متاح لابنك/ابنتك\.?').firstMatch(trimmed);
      if (match != null) {
        return 'A new exam "${match.group(1)}" is available for your child.';
      }

      // 3. Homework
      match = RegExp(r'تم تعيين واجب منزلي جديد "(.*?)"\.?').firstMatch(trimmed);
      if (match != null) {
        return 'New homework "${match.group(1)}" has been assigned.';
      }

      // 4. Grading
      match = RegExp(r'تم رصد نتيجة محاولتك في اختبار "(.*?)"\.\s*الدرجة:\s*(.+)').firstMatch(trimmed);
      if (match != null) {
        return 'Your attempt for "${match.group(1)}" has been graded. Score: ${match.group(2)}';
      }
      match = RegExp(r'تم تصحيح اختبار ابنك/ابنتك "(.*?)"\.\s*الدرجة:\s*(.+)').firstMatch(trimmed);
      if (match != null) {
        return 'Your child exam "${match.group(1)}" has been graded. Score: ${match.group(2)}';
      }
      match = RegExp(r'تم تصحيح تسليمك للواجب "(.*?)"\.\s*الدرجة:\s*(.+)').firstMatch(trimmed);
      if (match != null) {
        return 'Your submission for "${match.group(1)}" has been graded. Score: ${match.group(2)}';
      }

      // 5. Enrollment
      match = RegExp(r'تم تفعيل (?:اشتراكك|تسجيلك) في (?:مجموعة )?(.*?) بنجاح\.?').firstMatch(trimmed);
      if (match != null) {
        return 'Enrollment in ${match.group(1)} is now active.';
      }

      // 6. Schedule
      match = RegExp(r'تم تحديث جدول (?:مواعيد )?(.*?)\.\s*يُرجى مراجعة (?:جدولك الدراسي|جدول الحصص)\.?').firstMatch(trimmed);
      if (match != null) {
        return '${match.group(1)} schedule was updated. Please check your timetable.';
      }

      // 7. Absence
      match = RegExp(r'نحيطكم علماً بأن الطالب (.*?) \((.*?)\) تغيب عن حصة اليوم مع الأستاذ (.*?)\.?').firstMatch(trimmed);
      if (match != null) {
        return 'Notice: Student ${match.group(1)} (${match.group(2)}) was absent from today\'s session with teacher ${match.group(3)}.';
      }
      match = RegExp(r'نحيطكم علماً بتغيب الطالب (.*?) في كشف الحضور عن غرفة التدريس (.*?)\.?').firstMatch(trimmed);
      if (match != null) {
        return 'Notice: Student ${match.group(1)} was absent in attendance sheet for room ${match.group(2)}.';
      }

      // 8. Test notification
      if (trimmed.contains('نظام الإشعارات الفورية يعمل بكفاءة')) {
        return 'The push notification system is working properly on your device and ready to receive alerts.';
      }

      return trimmed;
    }
  }

  /// Localizes category badges ('أكاديمي', 'مالي كاش', 'تنبيه سنتر').
  static String localizeCategory(String label, {required bool isArabic}) {
    if (isArabic) {
      return switch (label.toLowerCase().trim()) {
        'academic' => 'أكاديمي',
        'financial' || 'finance' => 'مالي كاش',
        'general' || 'emergency' || 'center alert' => 'تنبيه سنتر',
        _ => label,
      };
    } else {
      return switch (label.trim()) {
        'أكاديمي' => 'Academic',
        'مالي كاش' => 'Financial',
        'تنبيه سنتر' => 'Center Alert',
        'طوارئ وعامة' => 'General & Alerts',
        _ => label,
      };
    }
  }
}
