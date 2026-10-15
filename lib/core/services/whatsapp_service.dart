import 'package:url_launcher/url_launcher.dart';

/// WhatsApp Integration Service specifically tailored for Egyptian Educational Centers.
/// Formats local phone numbers (010, 011, 012, 015) to international (+20) and dispatches official messages.
class WhatsAppService {
  WhatsAppService._();

  /// Cleans and formats phone numbers for WhatsApp URL scheme (e.g. 01012345678 -> 201012345678)
  static String formatEgyptianNumber(String phone) {
    var clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('01') && clean.length == 11) {
      clean = '2$clean';
    } else if (clean.startsWith('201') && clean.length == 12) {
      // Already correct
    } else if (clean.startsWith('00201')) {
      clean = clean.substring(2);
    }
    return clean;
  }

  /// Sends a preformatted WhatsApp message to a student or parent
  static Future<bool> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    final formattedNumber = formatEgyptianNumber(phoneNumber);
    if (formattedNumber.isEmpty) return false;

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = Uri.parse('https://wa.me/$formattedNumber?text=$encodedMessage');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Sends custom text to a phone number
  static Future<bool> sendCustomMessage({
    required String phone,
    required String message,
  }) {
    return sendMessage(phoneNumber: phone, message: message);
  }

  /// Dispatches an official absence notification message to the parent
  static Future<bool> sendAbsenceNotice({
    required String parentPhone,
    required String studentName,
    required String subjectName,
    required String centerName,
    String? sessionDate,
    String? contactPhone,
  }) {
    final dateStr = sessionDate ?? 'اليوم';
    final message = '''
السلام عليكم ورحمة الله وبركاته،
تحية طيبة من إدارة سنتر: *$centerName* 🏫

نود إحاطة حضراتكم علماً بغياب نجلكم/ابنتكم:
👤 الطالب: *$studentName*
📚 المادة: *$subjectName*
📅 التاريخ: $dateStr

حرصاً منا على مستواه الدراسي ومتابعة المنهج أولاً بأول، نرجو الاطمئنان عليه ومراجعة سبب الغياب.
${contactPhone != null && contactPhone.isNotEmpty ? '\n📞 للتواصل مع إدارة السنتر: $contactPhone' : ''}
مع تمنياتنا له بدوام التوفيق والنجاح.
'''.trim();

    return sendMessage(phoneNumber: parentPhone, message: message);
  }

  /// Dispatches an official exam / test grade result message to the parent
  static Future<bool> sendGradeNotice({
    required String parentPhone,
    required String studentName,
    required String examTitle,
    required num score,
    required num totalScore,
    required String centerName,
  }) {
    return sendExamResultToParent(
      parentPhone: parentPhone,
      studentName: studentName,
      examTitle: examTitle,
      score: score,
      maxScore: totalScore,
      centerName: centerName,
    );
  }

  /// Dispatches a comprehensive official exam result to the parent via WhatsApp
  /// perfectly formatted for Egyptian educational centers with teacher name, subject, rank, and encouragement.
  static Future<bool> sendExamResultToParent({
    required String parentPhone,
    required String studentName,
    required String examTitle,
    required num score,
    required num maxScore,
    required String centerName,
    String? subjectName,
    String? teacherName,
    int? rank,
    int? totalStudentsInGroup,
    String? groupName,
  }) {
    final max = maxScore > 0 ? maxScore : 1;
    final percentage = ((score / max) * 100).toStringAsFixed(1);
    final ratio = (score / max);

    String feedbackBadge;
    if (ratio >= 0.90) {
      feedbackBadge = '🌟 ما شاء الله! مستوى استثنائي وممتاز جداً، نرجو الاستمرار على هذا التفوق.';
    } else if (ratio >= 0.75) {
      feedbackBadge = '👏 نتيجة جيدة جداً، مع قليل من التركيز سيصل للدرجة النهائية بإذن الله.';
    } else if (ratio >= 0.50) {
      feedbackBadge = '💡 تم اجتياز الاختبار بنجاح، ونوصي بمزيد من المراجعة وحل التدريبات لرفع المستوى.';
    } else {
      feedbackBadge = '⚠️ النتيجة دون المستوى المتوقع، نرجو متابعة الطالب ومراجعة الأخطاء مع المدرس والمساعدين فوراً.';
    }

    final buffer = StringBuffer();
    buffer.writeln('السلام عليكم ورحمة الله وبركاته،');
    buffer.writeln('تحية طيبة من إدارة سنتر: *$centerName* 🏫');
    buffer.writeln('');
    buffer.writeln('نحيط سيادتكم علماً بنتيجة اختبار نجلكم/ابنتكم:');
    buffer.writeln('👤 الطالب: *$studentName*');
    buffer.writeln('📝 الاختبار: *$examTitle*');
    if (subjectName != null && subjectName.isNotEmpty) {
      buffer.writeln('📚 المادة: *$subjectName*');
    }
    if (teacherName != null && teacherName.isNotEmpty) {
      buffer.writeln('👨‍🏫 مع الأستاذ: *$teacherName*');
    }
    if (groupName != null && groupName.isNotEmpty) {
      buffer.writeln('👥 المجموعة: *$groupName*');
    }
    buffer.writeln('🎯 الدرجة: *$score من $maxScore* ($percentage%)');
    if (rank != null && rank > 0) {
      final totalSuffix = (totalStudentsInGroup != null && totalStudentsInGroup > 0)
          ? ' من إجمالي $totalStudentsInGroup طالب'
          : '';
      buffer.writeln('🏆 الترتيب على المجموعة: *المركز $rank$totalSuffix*');
    }
    buffer.writeln('');
    buffer.writeln(feedbackBadge);
    buffer.writeln('');
    buffer.writeln('شاكرين لسيادتكم حسن التعاون والمتابعة المستمرة لتحقيق أعلى الدرجات 🎓');

    return sendMessage(phoneNumber: parentPhone, message: buffer.toString().trim());
  }

  /// Sends a WhatsApp reminder to the parent if the student hasn't submitted their homework
  static Future<bool> sendHomeworkReminderToParent({
    required String parentPhone,
    required String studentName,
    required String homeworkTitle,
    required DateTime dueAt,
    required String centerName,
    String? subjectName,
    String? teacherName,
    String? groupName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('السلام عليكم ورحمة الله وبركاته،');
    buffer.writeln('تحية طيبة من إدارة سنتر: *$centerName* 🏫');
    buffer.writeln('');
    buffer.writeln('⚠️ *تنبيه هام بشأن تسليم الواجب المنزلي:*');
    buffer.writeln('نحيط سيادتكم علماً بأن الطالب: *$studentName* لم يقم بتسليم الواجب المطلوب منه حتى الآن:');
    buffer.writeln('📖 الواجب: *$homeworkTitle*');
    if (subjectName != null && subjectName.isNotEmpty) {
      buffer.writeln('📚 المادة: *$subjectName*');
    }
    if (teacherName != null && teacherName.isNotEmpty) {
      buffer.writeln('👨‍🏫 مع الأستاذ: *$teacherName*');
    }
    if (groupName != null && groupName.isNotEmpty) {
      buffer.writeln('👥 المجموعة: *$groupName*');
    }
    final formattedDue = '${dueAt.year}-${dueAt.month.toString().padLeft(2, '0')}-${dueAt.day.toString().padLeft(2, '0')} الساعة ${dueAt.hour.toString().padLeft(2, '0')}:${dueAt.minute.toString().padLeft(2, '0')}';
    buffer.writeln('⏰ آخر موعد لتسليم الواجب: *$formattedDue*');
    buffer.writeln('');
    buffer.writeln('نرجو من سيادتكم حث الطالب على حل الواجب وتسليمه في الموعد المحدد لضمان استيعاب الدرس ومتابعة درجات أعمال السنة ✍️');
    buffer.writeln('شاكرين تعاونكم الدائم معنا 🎓');

    return sendMessage(phoneNumber: parentPhone, message: buffer.toString().trim());
  }

  /// Sends a graded homework score & feedback report to the parent via WhatsApp
  static Future<bool> sendHomeworkResultToParent({
    required String parentPhone,
    required String studentName,
    required String homeworkTitle,
    required num score,
    required num maxScore,
    required String centerName,
    String? teacherFeedback,
    String? subjectName,
    String? teacherName,
    String? groupName,
  }) {
    final max = maxScore > 0 ? maxScore : 1;
    final percentage = ((score / max) * 100).toStringAsFixed(1);

    final buffer = StringBuffer();
    buffer.writeln('السلام عليكم ورحمة الله وبركاته،');
    buffer.writeln('تحية طيبة من إدارة سنتر: *$centerName* 🏫');
    buffer.writeln('');
    buffer.writeln('نحيط سيادتكم علماً بنتيجة تصحيح واجب نجلكم/ابنتكم:');
    buffer.writeln('👤 الطالب: *$studentName*');
    buffer.writeln('📖 الواجب: *$homeworkTitle*');
    if (subjectName != null && subjectName.isNotEmpty) {
      buffer.writeln('📚 المادة: *$subjectName*');
    }
    if (teacherName != null && teacherName.isNotEmpty) {
      buffer.writeln('👨‍🏫 مع الأستاذ: *$teacherName*');
    }
    if (groupName != null && groupName.isNotEmpty) {
      buffer.writeln('👥 المجموعة: *$groupName*');
    }
    buffer.writeln('🎯 الدرجة المحققة: *$score من $maxScore* ($percentage%)');
    if (teacherFeedback != null && teacherFeedback.trim().isNotEmpty) {
      buffer.writeln('💬 ملاحظات وتوجيه الأستاذ: _${teacherFeedback.trim()}_');
    }
    buffer.writeln('');
    buffer.writeln('نقدر التزام واجتهاد الطالب ونتمنى له دوام التوفيق والتميز دائماً 🌟');

    return sendMessage(phoneNumber: parentPhone, message: buffer.toString().trim());
  }

  /// Dispatches an urgent predictive academic intervention alert to the parent
  /// when a student shows declining exam trajectories or is at risk of falling behind.
  static Future<bool> sendAcademicInterventionAlertToParent({
    required String parentPhone,
    required String studentName,
    required String centerName,
    required String teacherName,
    required String subjectName,
    required String riskLevel,
    required List<String> recentScores,
    required String reason,
    String? recommendedAction,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('السلام عليكم ورحمة الله وبركاته،');
    buffer.writeln('تحية طيبة لحضرتك من الأستاذ *$teacherName* وإدارة سنتر: *$centerName* 🏫');
    buffer.writeln('');
    buffer.writeln('⚠️ *تقرير متابعة أكاديمية عاجل لنجلكم/ابنتكم:*');
    buffer.writeln('👤 الطالب: *$studentName*');
    buffer.writeln('📚 المادة: *$subjectName*');
    buffer.writeln('📊 حالة التقييم: *$riskLevel*');
    buffer.writeln('📉 ملاحظة المستوى: $reason');
    buffer.writeln('');
    buffer.writeln('📋 *نتائج آخر الاختبارات والواجبات:*');
    for (final score in recentScores) {
      buffer.writeln('• $score');
    }
    buffer.writeln('');
    buffer.writeln('💡 *خطة الدعم والمقترحات:*');
    buffer.writeln(recommendedAction ?? '1. التنسيق لحضور جلسة مراجعة مجانية مع المساعد الأكاديمي.\n2. إعادة اختبار النقاط الصعبة لرفع التحصيل.\n3. التأكيد على أداء الواجبات بانتظام.');
    buffer.writeln('');
    buffer.writeln('حرصنا الدائم على مصلحة ومستقبل الطالب هو دافعنا، نرجو التكرم بالتواصل معنا لتنسيق خطة الدعم.');
    buffer.writeln('مع أطيب التمنيات بالتوفيق والنجاح الدائم 🌟');

    return sendMessage(phoneNumber: parentPhone, message: buffer.toString().trim());
  }

  /// Dispatches an official digital cash receipt to the parent via WhatsApp
  static Future<bool> sendCashReceiptToParent({
    required String parentPhone,
    required String studentName,
    required String studentCode,
    required String receiptNo,
    required double amountPaid,
    required String purpose,
    required String centerName,
    String? cashierName,
    double? remainingBalance,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🏛️ *$centerName*');
    buffer.writeln('🧾 *إيصال سداد إلكتروني معتمد #$receiptNo*');
    buffer.writeln('───────────────────');
    buffer.writeln('👤 *الطالب:* $studentName (كود: $studentCode)');
    buffer.writeln('💵 *المبلغ المسدد:* ${amountPaid.toStringAsFixed(2)} ج.م');
    buffer.writeln('📌 *بند السداد:* $purpose');
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    buffer.writeln('📅 *التاريخ:* $dateStr');
    if (cashierName != null && cashierName.isNotEmpty) {
      buffer.writeln('✍️ *المستلم:* $cashierName');
    }
    if (remainingBalance != null && remainingBalance > 0) {
      buffer.writeln('⚠️ *المتبقي على الحساب:* ${remainingBalance.toStringAsFixed(2)} ج.م');
    } else {
      buffer.writeln('🟢 *حالة الحساب:* تم السداد بالكامل - لا توجد متأخرات ✔️');
    }
    buffer.writeln('───────────────────');
    buffer.writeln('شكراً لثقتكم بنا، ونتمنى لنجلكم التوفيق والتميز دائماً! 🌟');

    return sendMessage(phoneNumber: parentPhone, message: buffer.toString().trim());
  }

  /// Dispatches a welcome and registration card message with barcode code to new student
  static Future<bool> sendStudentWelcomeRegistrationCard({
    required String parentPhone,
    required String studentName,
    required String studentCode,
    required String centerName,
    required String gradeLevel,
    required List<String> enrolledGroups,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🎉 *أهلاً بك في أسرة $centerName!* 🏫');
    buffer.writeln('تم تسجيل الطالب بنجاح في المنظومة التعليمية.');
    buffer.writeln('───────────────────');
    buffer.writeln('👤 *اسم الطالب:* $studentName');
    buffer.writeln('🪪 *كود الطالب المعتمد:* *$studentCode*');
    buffer.writeln('📚 *المرحلة:* $gradeLevel');
    if (enrolledGroups.isNotEmpty) {
      buffer.writeln('👥 *المجموعات المسجلة:*');
      for (final g in enrolledGroups) {
        buffer.writeln('   • $g');
      }
    }
    buffer.writeln('───────────────────');
    buffer.writeln('📱 *تنبيه هام:* يرجى الاحتفاظ بكود الطالب ($studentCode) لإبرازه عند بوابات الدخول وتسجيل الحضور بالباركود.');
    buffer.writeln('مع أطيب تمنياتنا بعام دراسي حافل بالتفوق والنجاح! 🌟');

    return sendMessage(phoneNumber: parentPhone, message: buffer.toString().trim());
  }
}


