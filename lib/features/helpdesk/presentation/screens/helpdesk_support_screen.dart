import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/whatsapp_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class HelpdeskSupportScreen extends StatefulWidget {
  final String? centerName;
  final String? centerPhone;
  final String? centerWhatsapp;

  const HelpdeskSupportScreen({
    super.key,
    this.centerName,
    this.centerPhone,
    this.centerWhatsapp,
  });

  @override
  State<HelpdeskSupportScreen> createState() => _HelpdeskSupportScreenState();
}

class _HelpdeskSupportScreenState extends State<HelpdeskSupportScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _ticketTitleController = TextEditingController();
  final _ticketDescController = TextEditingController();
  String _selectedCategory = 'استفسار أكاديمي';
  bool _isSubmitting = false;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'كيف يتم سداد مصاريف الحصص والمجموعات؟',
      'answer': 'الدفع في السنتر يتم نقداً فقط (كاش) عند موظف الاستقبال أو الخزينة قبل بدء الحصة أو في الأسبوع الأول من كل شهر. يتم استلام إيصال إلكتروني فوري مدون به تفاصيل السداد.',
    },
    {
      'question': 'ماذا يحدث إذا تغيبت عن الحصة أو الامتحان؟',
      'answer': 'يتم إشعار ولي الأمر فوراً بالغياب عبر واتساب. في حالة وجود عذر مسبق (مرض أو سفر) يمكن لولي الأمر تسجيل طلب عذر غياب عبر التطبيق لتنسيق حصة تعويضية أو استلام تسجيل وشرح الحصة.',
    },
    {
      'question': 'كيف يمكنني استلام مذكرات وملازم المدرس؟',
      'answer': 'المذكرات الورقية متاحة في مخزن ومكتبة السنتر كاش، كما تتاح النسخة الرقمية المقروءة عبر التطبيق داخل مكتبة الملازم بعد حضور الحصة وسداد الرسوم.',
    },
    {
      'question': 'هل يمكن إعادة امتحان أو كويز لم أحضره؟',
      'answer': 'يمكن للمدرس أو مساعده (TA) فتح محاولة إعادة للامتحان (Reset Attempt) بعد مراجعة العذر المقدم من الطالب أو ولي الأمر.',
    },
    {
      'question': 'ما هي مواعيد عمل استقبال وسكرتارية السنتر؟',
      'answer': 'الاستقبال متاح يومياً من الساعة 8:00 صباحاً وحتى 9:00 مساءً للرد على كافة الاستفسارات وتسجيل الطلاب وتحصيل الرسوم.',
    },
  ];

  final List<Map<String, dynamic>> _myTickets = [
    {
      'id': 'TCK-201',
      'title': 'استفسار عن موعد مراجعة الفيزياء لغات',
      'category': 'استفسار أكاديمي',
      'status': 'تم الرد',
      'response': 'تم تحديد حصة المراجعة يوم الجمعة القادمة الساعة 3:00 عصراً بالقاعة الكبرى.',
      'date': '2026-10-12',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ticketTitleController.dispose();
    _ticketDescController.dispose();
    super.dispose();
  }

  void _submitTicket() {
    if (_ticketTitleController.text.trim().isEmpty || _ticketDescController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء كتابة عنوان وتفاصيل التذكرة بالكامل')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _myTickets.insert(0, {
          'id': 'TCK-${DateTime.now().millisecondsSinceEpoch % 1000}',
          'title': _ticketTitleController.text.trim(),
          'category': _selectedCategory,
          'status': 'قيد المراجعة',
          'response': null,
          'date': 'اليوم',
        });
        _ticketTitleController.clear();
        _ticketDescController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('تم إرسال تذكرتك لسكرتارية وإدارة السنتر بنجاح! سيتم الرد قريباً.'),
        ),
      );
    });
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final centerName = widget.centerName ?? 'سنتر الأوائل التعليمي';
    final centerPhone = widget.centerPhone ?? '01012345678';
    final centerWhatsapp = widget.centerWhatsapp ?? '01012345678';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('الدعم الفني والمساعدة 🎧'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.help_outline_rounded), text: 'الأسئلة الشائعة'),
            Tab(icon: Icon(Icons.confirmation_num_outlined), text: 'تذاكر المساعدة'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick Contacts Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.primary.withValues(alpha: 0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سكرتارية: $centerName',
                      style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'متاحون لمساعدتك يومياً (8 ص - 9 م)',
                      style: AppTypography.caption(textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.filled(
                      tooltip: 'اتصال هاتفياً',
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                      icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
                      onPressed: () => _makePhoneCall(centerPhone),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'تواصل عبر واتساب',
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                      icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                      onPressed: () {
                        WhatsAppService.sendCustomMessage(
                          phone: centerWhatsapp,
                          message: 'السلام عليكم ورحمة الله، أحتاج مساعدة أو استفسار بخصوص السنتر.',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // FAQ Tab
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _faqs.length,
                  itemBuilder: (context, i) {
                    final item = _faqs[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                          title: Text(
                            item['question']!,
                            style: AppTypography.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Text(
                                item['answer']!,
                                style: AppTypography.bodySmall(textSecondary).copyWith(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Tickets Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Create Ticket Card
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'فتح تذكرة مساعدة جديدة 📝',
                              style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'تصنيف المشكلة أو الطلب',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'استفسار أكاديمي', child: Text('استفسار أكاديمي أو دراسي')),
                                DropdownMenuItem(value: 'مشكلة مالية/إيصال', child: Text('مشكلة مالية أو إيصال سداد')),
                                DropdownMenuItem(value: 'مذكرات وملازم', child: Text('استلام مذكرات وملازم')),
                                DropdownMenuItem(value: 'عذر غياب', child: Text('إبلاغ عن عذر غياب')),
                                DropdownMenuItem(value: 'اقتراح أو شكوى', child: Text('اقتراح أو شكوى للإدارة')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _ticketTitleController,
                              decoration: const InputDecoration(
                                labelText: 'عنوان التذكرة باختصار',
                                prefixIcon: Icon(Icons.title_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _ticketDescController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'تفاصيل الطلب أو الاستفسار بالتفصيل...',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isSubmitting ? null : _submitTicket,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.send_rounded),
                                label: const Text('إرسال التذكرة للإدارة'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Existing Tickets list
                      Text(
                        'تذاكري السابقة (${_myTickets.length})',
                        style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ..._myTickets.map((tck) {
                        final isAnswered = tck['status'] == 'تم الرد';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#${tck['id']} • ${tck['category']}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isAnswered ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tck['status'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isAnswered ? Colors.green.shade800 : Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tck['title'],
                                  style: AppTypography.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (tck['response'] != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.support_agent_rounded, color: Colors.green, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'رد السكرتارية: ${tck['response']}',
                                            style: TextStyle(fontSize: 12, color: Colors.green.shade900, height: 1.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
