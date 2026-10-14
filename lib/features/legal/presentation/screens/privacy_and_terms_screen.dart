import 'package:flutter/material.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

/// Screen presenting the Center Privacy Policy, Student Data Security,
/// and Terms of Service. Fully compliant with Google Play & Apple App Store guidelines.
class PrivacyAndTermsScreen extends StatefulWidget {
  final int initialTabIndex;

  const PrivacyAndTermsScreen({super.key, this.initialTabIndex = 0});

  static Future<void> show(BuildContext context, {int initialTabIndex = 0}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivacyAndTermsScreen(initialTabIndex: initialTabIndex),
      ),
    );
  }

  @override
  State<PrivacyAndTermsScreen> createState() => _PrivacyAndTermsScreenState();
}

class _PrivacyAndTermsScreenState extends State<PrivacyAndTermsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'سياسة الخصوصية والشروط',
          style: AppTypography.titleLarge(textPrimary).copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: '🛡️ الخصوصية'),
                Tab(text: '📋 شروط الخدمة'),
                Tab(text: '🔒 حماية وسرية البيانات'),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: TabBarView(
            controller: _tabController,
            children: [
              _PrivacyTab(isDark: isDark),
              _TermsTab(isDark: isDark),
              _SecurityAndRightsTab(isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyTab extends StatelessWidget {
  final bool isDark;

  const _PrivacyTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildHeroBanner(
          icon: Icons.shield_rounded,
          color: AppColors.primary,
          title: 'سياسة الخصوصية وأمان السنتر التعليمي',
          subtitle:
              'تلتزم منصة Brivio بحماية خصوصية الطلاب، أولياء الأمور، المدرسين، وإدارات السناتر التعليمية وفقاً لأعلى معايير حماية البيانات والشفافية.',
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          isDark: isDark,
          title: '1. البيانات التي نجمعها',
          items: const [
            'البيانات الأساسية: الاسم، رقم الهاتف (للتواصل وإرسال إشعارات الواتساب والحضور)، والمرحلة الدراسية.',
            'السجلات الأكاديمية: الحضور والغياب، نتائج الاختبارات، الواجبات المنزلية، والتقييمات الدورية.',
            'السجلات المالية: مدفوعات الحصص والاشتراكات النقدية داخل السنتر، وإيصالات القبض الإلكترونية الصادرة.',
            'السبورة التفاعلية: شروحات المدرس المنشورة للمجموعة، وملاحظات الطالب الخاصة في مسودته الشخصية.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          isDark: isDark,
          title: '2. كيف نستخدم بياناتك؟',
          items: const [
            'إدارة العمليات التعليمية داخل السنتر وتسجيل الحضور بالـ QR عند باب السنتر.',
            'إرسال إشعارات الغياب والتنبيهات المباشرة لأولياء الأمور عبر واتساب والإشعارات الفورية.',
            'تمكين المدرس من متابعة استيعاب الطلاب ونتائج الامتحانات وتصفية مستحقات الحصص.',
            'تمكين الطالب من استعراض المناهج الدراسية، والحل في مسودته وسبورته الشخصية دون تشتيت.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          isDark: isDark,
          title: '3. عدم مشاركة البيانات مع أطراف ثالثة',
          items: const [
            'نحن لا نبيع ولا نؤجر ولا نشارك أي بيانات شخصية أو أرقام هواتف مع أي جهة إعلانية أو تجارية إطلاقاً.',
            'جميع البيانات تظل محصورة بدقة داخل السنتر التعليمي المقيد به الطالب والمدرس.',
          ],
        ),
      ],
    );
  }
}

class _TermsTab extends StatelessWidget {
  final bool isDark;

  const _TermsTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildHeroBanner(
          icon: Icons.gavel_rounded,
          color: AppColors.warning,
          title: 'شروط وأحكام الاستخدام والخدمة',
          subtitle:
              'يحدد هذا الاتفاق القواعد المنظمة لاستخدام منصة إدارة السناتر التعليمية لجميع الأطراف المعنية.',
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          isDark: isDark,
          title: '1. حسابات الطلاب وأولياء الأمور',
          items: const [
            'يتحمل كل مستخدم مسؤولية الحفاظ على سرية كود الدخول الخاص به.',
            'بطاقة الهوية الرقمية (QR) مخصصة للاستخدام الشخصي للطالب عند بوابة السنتر ولا يجوز مشاركتها.',
            'يحق لولي الأمر الاطلاع الدائم على سجل حضور وغياب ودرجات ابنه/ابنته في أي وقت.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          isDark: isDark,
          title: '2. المعاملات المالية ودفع الاشتراكات',
          items: const [
            'يتم تحصيل جميع المصاريف واشتراكات الحصص نقداً (كاش) داخل مقر السنتر أو عبر السكرتارية الرسمية.',
            'يعد الإيصال الإلكتروني الصادر من التطبيق مرجعاً رسمياً معتمداً لعملية التحصيل والتصفية المالية.',
            'تتم تصفية نسب المدرسين والسنتر وفق الاتفاق المعتمد لكل مجموعة دراسية.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          isDark: isDark,
          title: '3. الملكية الفكرية للمحتوى والدروس',
          items: const [
            'تظل المذكرات، الامتحانات، وشروحات السبورة المنشورة ملكاً فكرياً للمدرس والسنتر التعليمي.',
            'يُمنع نسخ أو إعادة بيع أو استغلال المحتوى التعليمي خارج نطاق السنتر دون إذن خطي.',
          ],
        ),
      ],
    );
  }
}

class _SecurityAndRightsTab extends StatelessWidget {
  final bool isDark;

  const _SecurityAndRightsTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildHeroBanner(
          icon: Icons.lock_person_rounded,
          color: AppColors.success,
          title: 'الأمان والسرية وحقوق المستخدم',
          subtitle:
              'ضمان كامل لسرية ملاحظات الطلاب، وعزل البيانات، وحق حذف الحساب طبقاً لمتطلبات Apple و Google.',
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          isDark: isDark,
          title: '1. سرية سبورة وملاحظات الطالب (100% Private)',
          items: const [
            'شروحات المدرس في الدرس تكون للقراءة والمتابعة لجميع طلاب المجموعة.',
            'جميع الملاحظات، الخربشات، وحلول التمارين التي يكتبها الطالب داخل طبقته الخاصة أو سبورته الشخصية هي سرية تماماً 100%.',
            'لا يمكن للمدرس، أو إدارة السنتر، أو بقية الزملاء رؤية مسودة الطالب أو ما يكتبه فيها.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          isDark: isDark,
          title: '2. عزل بيانات السناتر (Multi-Tenant Isolation)',
          items: const [
            'كل سنتر يعمل ككيان مستقل ومعزول تماماً عن أي سنتر تعليمي آخر.',
            'لا يمكن لأي سنتر الوصول لبيانات أو طلاب سنتر آخر إلا بموافقة صريحة عبر شراكة رسمية موثقة.',
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          isDark: isDark,
          title: '3. حق حذف الحساب والبيانات (Right to Erasure)',
          items: const [
            'يحق لأي مستخدم (طالب، مدرس، أو ولي أمر) طلب حذف حسابه وجميع بياناته المرتبطة في أي وقت مباشرة من شاشة الإعدادات.',
            'عند تأكيد الحذف، يتم إزالة ملف التعريف الشخصي، والجلسات النشطة، وسجلات الدخول نهائياً.',
          ],
        ),
      ],
    );
  }
}

Widget _buildHeroBanner({
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionCard({
  required bool isDark,
  required String title,
  required List<String> items,
}) {
  final surfaceColor =
      isDark ? AppColors.darkSurface : AppColors.lightSurface;
  final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
  final textPrimary =
      isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  final textSecondary =
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  return GlassCard(
    padding: const EdgeInsets.all(20),
    color: surfaceColor,
    borderColor: borderColor,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.titleMedium(textPrimary).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 14),
        for (final item in items) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: AppTypography.bodyMedium(textSecondary).copyWith(
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
