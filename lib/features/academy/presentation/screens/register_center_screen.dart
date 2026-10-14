import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../data/repositories/supabase_center_repository.dart';

class RegisterCenterScreen extends StatefulWidget {
  const RegisterCenterScreen({super.key});

  @override
  State<RegisterCenterScreen> createState() => _RegisterCenterScreenState();
}

class _RegisterCenterScreenState extends State<RegisterCenterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _centerNameCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _selectedGovernorate = 'القاهرة';
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  static const List<String> _governorates = [
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'الدقهلية',
    'الشرقية',
    'القليوبية',
    'الغربية',
    'المنوفية',
    'البحيرة',
    'كفر الشيخ',
    'دمياط',
    'بورسعيد',
    'الإسماعيلية',
    'السويس',
    'الفيوم',
    'بني سويف',
    'المنيا',
    'أسيوط',
    'سوهاج',
    'قنا',
    'الأقصر',
    'أسوان',
    'مطروح',
    'البحر الأحمر',
    'شمال سيناء',
    'جنوب سيناء',
    'الوادي الجديد',
  ];

  @override
  void dispose() {
    _centerNameCtrl.dispose();
    _adminNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      final adminName = _adminNameCtrl.text.trim();
      final centerName = _centerNameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();

      // 1. Authenticate or Sign Up user via Supabase Auth
      String? userId;
      if (client.auth.currentUser != null) {
        userId = client.auth.currentUser!.id;
      } else {
        try {
          final authRes = await client.auth.signUp(
            email: email,
            password: password,
            data: {'full_name': adminName, 'phone_number': phone},
          );

          userId = authRes.user?.id;
          if (userId == null) {
            throw Exception('تعذر إنشاء حساب المسؤول، يرجى المحاولة مرة أخرى.');
          }

          // Try signing in immediately (works if email confirmation is disabled or session is provided)
          if (client.auth.currentSession == null) {
            try {
              final signInRes = await client.auth.signInWithPassword(
                email: email,
                password: password,
              );
              userId = signInRes.user?.id ?? userId;
            } catch (_) {
              // Email confirmation may be enabled in Supabase; userId is preserved
            }
          }
        } on AuthException catch (e) {
          final msg = e.message.toLowerCase();
          if (msg.contains('already registered') || msg.contains('already exists')) {
            final signInRes = await client.auth.signInWithPassword(
              email: email,
              password: password,
            );
            userId = signInRes.user?.id ?? client.auth.currentUser?.id;
          } else {
            rethrow;
          }
        }
      }

      if (userId == null) {
        throw Exception('تعذر التحقق من حساب المستخدم، يرجى إعادة المحاولة.');
      }

      // 2. Call multi-tenant onboarding RPC
      final repo = SupabaseCenterRepository(SupabaseClientWrapper(client));
      final result = await repo.registerCenter(
        centerName: centerName,
        adminName: adminName,
        phoneNumber: phone,
        governorate: _selectedGovernorate,
        userId: userId,
      );

      if (!mounted) return;

      final centerCode = result['center_code']?.toString() ?? '';
      final hasActiveSession = client.auth.currentSession != null;

      // 3. Show Success Dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('تم إنشاء السنتر بنجاح!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أهلاً بك في نظام إدارة السناتر! تم تجهيز قاعدة بيانات خاصة ومستقلة تماماً لسنترك: "$centerName".',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_rounded, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('كود السنتر الفريد (للربط ودخول الطلاب):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(centerCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!hasActiveSession) ...[
                const SizedBox(height: 12),
                const Text(
                  'ملاحظة: تم إنشاء السنتر بنجاح! إذا كانت ميزة تأكيد البريد الإلكتروني مفعلة في مشروعك، يرجى تأكيد حسابك أو تسجيل الدخول مباشرة.',
                  style: TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
              child: Text(hasActiveSession ? 'الدخول للوحة التحكم' : 'الذهاب لتسجيل الدخول'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسجيل سنتر تعليمي جديد'),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDark,
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.apartment_rounded, size: 48, color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              'ابدأ إدارة سنترك باحترافية وسهولة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'بيانات منفصلة بالكامل • نظام حضور سريع • حسابات للمدرسين والطلاب',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade400),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Form Fields
                      TextFormField(
                        controller: _centerNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'اسم السنتر التعليمي *',
                          hintText: 'مثال: سنتر الأوائل التعليمي',
                          prefixIcon: const Icon(Icons.school_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم السنتر' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _adminNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'اسم المدير أو صاحب السنتر *',
                          hintText: 'مثال: أ / أحمد محمود',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم المسؤول' : null,
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        initialValue: _selectedGovernorate,
                        decoration: InputDecoration(
                          labelText: 'المحافظة *',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _governorates
                            .map((gov) => DropdownMenuItem(value: gov, child: Text(gov)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedGovernorate = v);
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'رقم هاتف السنتر / واتساب *',
                          hintText: 'مثال: 01012345678',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال رقم الهاتف' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني لحساب الإدارة *',
                          hintText: 'admin@center.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                          if (!v.contains('@')) return 'يرجى إدخال بريد إلكتروني صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور *',
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'يرجى إدخال كلمة المرور';
                          if (v.length < 6) return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _handleRegister,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isLoading ? 'جاري تجهيز السنتر...' : 'إنشاء السنتر والبدء فوراً',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Back to login
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('لديك حساب بالفعل؟ تسجيل الدخول'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
