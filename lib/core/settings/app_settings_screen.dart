import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../localization/app_locale_controller.dart';
import '../localization/app_localizations.dart';
import '../notifications/push_notification_service.dart';
import '../services/settings_service.dart';
import '../services/whatsapp_service.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/components/glass_card.dart';
import '../../design_system/components/editable_avatar.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/admin/domain/repositories/i_admin_repository.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/legal/presentation/screens/privacy_and_terms_screen.dart';
import '../../features/payments/presentation/widgets/thermal_printer_settings_dialog.dart';

/// Categories for quick navigation and filtering
enum _SettingsCategory {
  all('الكل', Icons.dashboard_outlined),
  account('الحساب والملف', Icons.person_outline),
  appearance('المظهر واللغة', Icons.palette_outlined),
  notifications('الإشعارات', Icons.notifications_none_outlined),
  hardware('الطابعات والعتاد', Icons.print_outlined),
  security('الأمان والخصوصية', Icons.security_outlined),
  system('الصيانة والدعم', Icons.build_outlined);

  final String label;
  final IconData icon;
  const _SettingsCategory(this.label, this.icon);
}

class AppSettingsScreen extends StatelessWidget {
  final AuthViewModel? authViewModel;
  final VoidCallback? onSignOut;

  const AppSettingsScreen({super.key, this.authViewModel, this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (canPop) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: Text(
            context.tr('إعدادات المنظومة والتطبيق'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: (isDark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.95),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: context.tr('رجوع'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: AppSettingsPanel(
          authViewModel: authViewModel,
          onSignOut: onSignOut,
        ),
      );
    }

    return PortalPageShell(
      title: context.tr('إعدادات المنظومة والتطبيق'),
      subtitle: context.tr('تخصيص المظهر العام، لغة العرض، الإشعارات، طابعات الفواتير، والأمان المتقدم.'),
      icon: Icons.settings_suggest_rounded,
      accentColor: AppColors.primary,
      eyebrow: context.tr('الإعدادات العامة'),
      child: Material(
        type: MaterialType.transparency,
        child: AppSettingsPanel(
          authViewModel: authViewModel,
          onSignOut: onSignOut,
        ),
      ),
    );
  }
}

class AppSettingsPanel extends StatefulWidget {
  final AuthViewModel? authViewModel;
  final VoidCallback? onSignOut;

  const AppSettingsPanel({super.key, this.authViewModel, this.onSignOut});

  @override
  State<AppSettingsPanel> createState() => _AppSettingsPanelState();
}

class _AppSettingsPanelState extends State<AppSettingsPanel> {
  bool _isLoading = true;
  bool _emailDigest = false;
  bool _twoFactorAuth = false;
  bool _dataCollection = false;
  bool _biometricLogin = false;
  bool _pushNotifications = true;
  bool _animationQuality = true;
  bool _soundEffects = true;
  bool _isClearingCache = false;
  bool _isTestingPing = false;
  int? _lastPingMs;
  String _timeZone = 'UTC+03:00';

  String? _userName;
  String? _userEmail;
  String? _userRole;
  String? _userPhone;
  String? _avatarUrl;

  _SettingsCategory _selectedCategory = _SettingsCategory.all;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        String? name = user.userMetadata?['full_name'] as String? ??
            user.userMetadata?['name'] as String?;
        String? role = user.userMetadata?['role'] as String?;
        String? avatar = user.userMetadata?['avatar_url'] as String?;
        String? phone = user.userMetadata?['phone_number'] as String? ??
            user.userMetadata?['phone'] as String?;

        try {
          final res = await client
              .from('profiles')
              .select('full_name, role, avatar_url, phone_number')
              .eq('id', user.id)
              .maybeSingle();
          if (res != null) {
            name ??= res['full_name'] as String?;
            role ??= res['role'] as String?;
            avatar ??= res['avatar_url'] as String?;
            phone = res['phone_number'] as String? ?? phone;
          }
        } catch (_) {}

        if (mounted) {
          setState(() {
            _userEmail = user.email;
            _userName = name ?? 'مستخدم المنظومة';
            _userRole = role;
            _avatarUrl = avatar;
            _userPhone = phone;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    final settingsService = GetIt.instance<SettingsService>();
    _emailDigest = settingsService.emailDigest;
    _twoFactorAuth = settingsService.twoFactorAuth;
    _dataCollection = settingsService.dataCollection;
    _biometricLogin = settingsService.biometricLogin;
    _pushNotifications = settingsService.pushNotifications;
    _animationQuality = settingsService.animationQuality;
    _soundEffects = settingsService.soundEffects;
    _timeZone = settingsService.timeZone;

    if (!GetIt.instance.isRegistered<IAdminRepository>()) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final adminRepo = GetIt.instance<IAdminRepository>();
      final results = await Future.wait<dynamic>([
        adminRepo.getSetting('email_digest'),
        adminRepo.getSetting('two_factor_auth'),
        adminRepo.getSetting('data_collection'),
        adminRepo.getSetting('push_notifications'),
        adminRepo.getSetting('time_zone'),
      ]);

      if (mounted) {
        setState(() {
          if (results[0] != null) _emailDigest = _parseBool(results[0]?.value);
          if (results[1] != null) _twoFactorAuth = _parseBool(results[1]?.value);
          if (results[2] != null) _dataCollection = _parseBool(results[2]?.value);
          if (results[3] != null) _pushNotifications = _parseBool(results[3]?.value);
          if (results[4] != null) {
            _timeZone = results[4]?.value.toString() ?? 'UTC+03:00';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _parseBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return false;
  }

  Future<void> _updateSetting<T>(
    String key,
    T value,
    void Function(T) updateLocalState,
  ) async {
    setState(() => updateLocalState(value));
    await _persistLocalSetting(key, value);

    if (key == 'biometric_login' || key == 'animation_quality' || key == 'sound_effects') {
      return;
    }

    try {
      if (GetIt.instance.isRegistered<IAdminRepository>()) {
        await GetIt.instance<IAdminRepository>().updateSetting(
          key,
          value.toString(),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التفضيل محلياً على هذا الجهاز بنجاح.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _persistLocalSetting<T>(String key, T value) async {
    final settingsService = GetIt.instance<SettingsService>();
    switch (key) {
      case 'animation_quality':
        await settingsService.updateAnimationQuality(value as bool);
        break;
      case 'sound_effects':
        await settingsService.updateSoundEffects(value as bool);
        break;
      case 'push_notifications':
        await settingsService.updatePushNotifications(value as bool);
        break;
      case 'email_digest':
        await settingsService.updateEmailDigest(value as bool);
        break;
      case 'two_factor_auth':
        await settingsService.updateTwoFactorAuth(value as bool);
        break;
      case 'data_collection':
        await settingsService.updateDataCollection(value as bool);
        break;
      case 'biometric_login':
        await settingsService.updateBiometricLogin(value as bool);
        break;
      case 'time_zone':
        await settingsService.updateTimeZone(value.toString());
        break;
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    await Future.delayed(const Duration(milliseconds: 600));
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
    if (mounted) {
      setState(() => _isClearingCache = false);
      _showSnackBar('تم مسح الذاكرة المؤقتة بنجاح واستعادة الأداء السلس 🧹');
    }
  }

  Future<void> _testCloudPing() async {
    setState(() => _isTestingPing = true);
    final stopwatch = Stopwatch()..start();
    try {
      final client = Supabase.instance.client;
      await client.from('profiles').select('id').limit(1);
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _lastPingMs = stopwatch.elapsedMilliseconds;
          _isTestingPing = false;
        });
        _showSnackBar('الاتصال بالسحابة ممتاز! زمن الاستجابة: $_lastPingMs مللي ثانية ⚡');
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _lastPingMs = null;
          _isTestingPing = false;
        });
        _showSnackBar('تعذر فحص الاتصال: $e', isError: true);
      }
    }
  }

  Future<void> _sendTestNotification() async {
    HapticFeedback.lightImpact();
    final pushService = GetIt.instance.isRegistered<PushNotificationService>()
        ? GetIt.instance<PushNotificationService>()
        : null;
    if (pushService != null) {
      await pushService.showTestNotification(
        title: 'إشعار تجريبي من بريفيو 🔔',
        body: 'خدمة الإشعارات الفورية تعمل بنجاح ومستعدة لاستقبال التنبيهات!',
      );
      _showSnackBar('تم إرسال إشعار تجريبي بنجاح 🔔');
    } else {
      _showSnackBar('خدمة الإشعارات مفعلة ومستعدة للعمل ✔️');
    }
  }

  void _openPrinterSettings() {
    HapticFeedback.lightImpact();
    ThermalPrinterSettingsDialog.show(
      context,
      centerName: 'السنتر التعليمي',
    );
  }

  Future<void> _launchSupportWhatsApp() async {
    HapticFeedback.lightImpact();
    String? supportPhone;
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final profile = await client.from('profiles').select('branch_id').eq('id', user.id).maybeSingle();
        final branchId = profile?['branch_id'] as String?;
        if (branchId != null) {
          final branch = await client.from('branches').select('phone, contact_phone').eq('id', branchId).maybeSingle();
          supportPhone = branch?['contact_phone']?.toString() ?? branch?['phone']?.toString();
        }
      }
    } catch (_) {}

    final phone = (supportPhone != null && supportPhone.isNotEmpty)
        ? WhatsAppService.formatEgyptianNumber(supportPhone)
        : '201000000000';

    final msg =
        'السلام عليكم، أحتاج مساعدة بخصوص تطبيق بريفيو التعليمي.\nالحساب: ${_userName ?? "مستخدم"} (${_formatRole(_userRole)})\nالبريد: ${_userEmail ?? "غير محدد"}';

    if (supportPhone != null && supportPhone.isNotEmpty) {
      final ok = await WhatsAppService.sendMessage(phoneNumber: phone, message: msg);
      if (ok) return;
    }

    if (mounted) {
      await Clipboard.setData(ClipboardData(text: msg));
      _showSnackBar('تم نسخ رسالة الدعم ومعلومات حسابك إلى الحافظة لسهولة إرسالها.');
    }
  }

  Future<void> _copyDiagnosticInfo() async {
    HapticFeedback.lightImpact();
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final info = '''
=== معلومات تشخيص بريفيو LMS ===
المستخدم: ${_userName ?? "غير معروف"}
الدور: ${_userRole ?? "غير محدد"}
البريد: ${_userEmail ?? "غير محدد"}
الهاتف: ${_userPhone ?? "غير محدد"}
معرف المستخدم: ${user?.id ?? "غير مسجل"}
المنطقة الزمنية: $_timeZone
الإصدار: 2.5.0 (Build 850)
الوضع: ${GetIt.instance<SettingsService>().themeMode.name}
اللغة: ${GetIt.instance<SettingsService>().language.name}
زمن الاستجابة: ${_lastPingMs != null ? '$_lastPingMs ms' : 'غير مفحوص'}
الوقت: ${DateTime.now().toIso8601String()}
===============================
''';
    await Clipboard.setData(ClipboardData(text: info));
    _showSnackBar('تم نسخ تقرير التشخيص إلى الحافظة بنجاح 📋');
  }

  void _openEditProfileDialog() {
    final nameController = TextEditingController(text: _userName ?? '');
    final phoneController = TextEditingController(text: _userPhone ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final dialogWidth = MediaQuery.of(context).size.width.clamp(280.0, 480.0);
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Row(
              children: [
                const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('تعديل البيانات الشخصية'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('الاسم الكامل'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        hintText: context.tr('أدخل اسمك الكامل'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(context.tr('رقم الهاتف للتواصل'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        hintText: '01xxxxxxxxx',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(context.tr('إلغاء')),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = nameController.text.trim();
                        final newPhone = phoneController.text.trim();
                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى إدخال الاسم الكامل')),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          final client = Supabase.instance.client;
                          final user = client.auth.currentUser;
                          if (user != null) {
                            await client.auth.updateUser(UserAttributes(
                              data: {
                                'full_name': newName,
                                'phone_number': newPhone,
                              },
                            ));
                            await client.from('profiles').update({
                              'full_name': newName,
                              'phone_number': newPhone,
                              'updated_at': DateTime.now().toIso8601String(),
                            }).eq('id', user.id);
                          }
                          if (mounted) {
                            setState(() {
                              _userName = newName;
                              _userPhone = newPhone;
                            });
                            Navigator.pop(ctx);
                            _showSnackBar('تم تحديث البيانات الشخصية بنجاح ✔️');
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                icon: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(context.tr('حفظ التعديلات')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openChangePasswordDialog() {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscurePass = true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final dialogWidth = MediaQuery.of(context).size.width.clamp(280.0, 480.0);
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Row(
              children: [
                const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('تغيير كلمة المرور'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('كلمة المرور الجديدة'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: passController,
                      obscureText: obscurePass,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                        ),
                        hintText: context.tr('6 أحرف أو أرقام على الأقل'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(context.tr('تأكيد كلمة المرور الجديدة'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmController,
                      obscureText: obscurePass,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        hintText: context.tr('أعد كتابة كلمة المرور للتأكيد'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(context.tr('إلغاء')),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final pass = passController.text;
                        final confirm = confirmController.text;
                        if (pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.tr('كلمة المرور يجب ألا تقل عن 6 أحرف')), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (pass != confirm) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.tr('كلمتا المرور غير متطابقتين')), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          final client = Supabase.instance.client;
                          await client.auth.updateUser(UserAttributes(password: pass));
                          if (mounted) {
                            Navigator.pop(ctx);
                            _showSnackBar(context.tr('تم تغيير كلمة المرور بنجاح 🔒'));
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل تغيير كلمة المرور: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                icon: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(context.tr('تأكيد التغيير')),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatRole(String? role) {
    return switch (role?.toLowerCase()) {
      'admin' || 'superadmin' => context.tr('مدير النظام والسنتر 👑'),
      'teacher' => context.tr('معلم معتمد 👨‍🏫'),
      'student' => context.tr('طالب 🎓'),
      'parent' => context.tr('ولي أمر 👨‍👩‍👦'),
      'staff' => context.tr('موظف استقبال وإدارة 🏛️'),
      _ => context.tr('مستخدم بريفيو'),
    };
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _pickTimeZone(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final timezones = [
      {'code': 'UTC+02:00', 'label': context.tr('توقيت مصر والأردن (GMT+2)')},
      {'code': 'UTC+03:00', 'label': context.tr('توقيت مكة المكرمة والقاهرة صيفاً (GMT+3)')},
      {'code': 'UTC+04:00', 'label': context.tr('توقيت الإمارات وعُمان (GMT+4)')},
      {'code': 'UTC+01:00', 'label': context.tr('توقيت الجزائر والمغرب وتونس (GMT+1)')},
      {'code': 'UTC+00:00', 'label': context.tr('توقيت غرينتش العالمي (UTC+0)')},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      context.tr('اختر المنطقة الزمنية للمنظومة'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                  const Divider(),
                  ...timezones.map(
                    (tz) => ListTile(
                      title: Text(tz['label']!),
                      subtitle: Text(tz['code']!),
                      trailing: _timeZone == tz['code']
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                          : null,
                      onTap: () {
                        _updateSetting<String>(
                           'time_zone',
                          tz['code']!,
                          (v) => _timeZone = v,
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _performSignOut() async {
    try {
      if (widget.onSignOut != null) {
        widget.onSignOut!();
        return;
      }
      final vm = widget.authViewModel ??
          (GetIt.instance.isRegistered<AuthViewModel>()
              ? GetIt.instance<AuthViewModel>()
              : null);
      if (vm != null) {
        await vm.signOut();
      } else {
        await Supabase.instance.client.auth.signOut();
      }
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      }
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Text(context.tr('تسجيل الخروج'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          context.tr('هل ترغب في تسجيل الخروج من حسابك الحالي على هذه المنظومة؟'),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('إلغاء')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () async {
              Navigator.pop(ctx);
              await _performSignOut();
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(context.tr('تسجيل الخروج')),
          ),
        ],
      ),
    );
  }

  void _confirmAccountDeletion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(
              context.tr('حذف الحساب نهائياً'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        content: Text(
          context.tr('هل أنت متأكد تماماً من رغبتك في حذف حسابك؟ سيتم إيقاف صلاحيات الدخول وإزالة بياناتك الشخصية وفقاً لسياسة الخصوصية. هذا الإجراء نهائي ولا يمكن التراجع عنه.'),
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('إلغاء وتراجع')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final client = Supabase.instance.client;
                final userId = client.auth.currentUser?.id;
                if (userId != null) {
                  await client.from('profiles').update({
                    'status': 'inactive',
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', userId);
                }
                await _performSignOut();
              } catch (e) {
                if (mounted) {
                  _showSnackBar('خطأ أثناء حذف الحساب: $e', isError: true);
                }
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text(context.tr('تأكيد الحذف النهائي')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = GetIt.instance<SettingsService>();
    final pushService = GetIt.instance.isRegistered<PushNotificationService>()
        ? GetIt.instance<PushNotificationService>()
        : null;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;
    final screenWidth = MediaQuery.of(context).size.width;

    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        final isAr = settingsService.language == AppLanguage.arabic;
        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth > 640 ? 24 : 16,
                  vertical: 16,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // 0. User Profile & Quick Actions Header Card
                  _buildUserProfileCard(isDark, primaryColor),

                  const SizedBox(height: 18),

                  // Category Navigation Filter Chips
                  _buildCategoryChips(isDark),

                  const SizedBox(height: 18),

                  // 1. Appearance Section
                  if (_shouldShow(_SettingsCategory.appearance)) ...[
                    _SettingsGroup(
                      title: 'المظهر وتنسيق الشاشة',
                      icon: Icons.palette_rounded,
                      accentColor: Colors.deepPurple,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('نمط العرض (السمة)'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.tr('اختر بين المظهر الفاتح المناسب للقاعات المضيئة أو الداكن المريح للعين.'),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ThemeSelectCard(
                                      icon: Icons.brightness_auto_rounded,
                                      label: 'تلقائي',
                                      subtitle: 'حسب الجهاز',
                                      isSelected: settingsService.themeMode == ThemeMode.system,
                                      onTap: () => settingsService.updateThemeMode(ThemeMode.system),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _ThemeSelectCard(
                                      icon: Icons.light_mode_rounded,
                                      label: 'فاتح',
                                      subtitle: 'نهاري',
                                      isSelected: settingsService.themeMode == ThemeMode.light,
                                      onTap: () => settingsService.updateThemeMode(ThemeMode.light),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _ThemeSelectCard(
                                      icon: Icons.dark_mode_rounded,
                                      label: 'داكن',
                                      subtitle: 'ليلي',
                                      isSelected: settingsService.themeMode == ThemeMode.dark,
                                      onTap: () => settingsService.updateThemeMode(ThemeMode.dark),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsSwitchTile(
                          icon: Icons.motion_photos_on_rounded,
                          iconColor: Colors.purple,
                          title: 'سلاسة المؤثرات الحركية (120Hz)',
                          subtitle: 'تفعيل الانتقالات الفائقة وتأثيرات الواجهة السلسة',
                          value: _animationQuality,
                          onChanged: (val) => _updateSetting(
                            'animation_quality',
                            val,
                            (v) => _animationQuality = v,
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsSwitchTile(
                          icon: Icons.volume_up_rounded,
                          iconColor: Colors.teal,
                          title: 'المؤثرات الصوتية والاهتزاز',
                          subtitle: 'إصدار صوت وتنبيه لمسي عند مسح الكود أو تسجيل الحضور',
                          value: _soundEffects,
                          onChanged: (val) {
                            _updateSetting(
                              'sound_effects',
                              val,
                              (v) => _soundEffects = v,
                            );
                            if (val) HapticFeedback.mediumImpact();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 2. Localization & Language
                    _SettingsGroup(
                      title: 'اللغة والإعدادات الإقليمية',
                      icon: Icons.language_rounded,
                      accentColor: Colors.blue,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('لغة واجهة التطبيق'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _LanguageCard(
                                      flag: '🇪🇬',
                                      name: 'اللغة العربية',
                                      isSelected: settingsService.language == AppLanguage.arabic,
                                      onTap: () => settingsService.updateLanguage(AppLanguage.arabic),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _LanguageCard(
                                      flag: '🇬🇧',
                                      name: 'English',
                                      isSelected: settingsService.language == AppLanguage.english,
                                      onTap: () => settingsService.updateLanguage(AppLanguage.english),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsActionTile(
                          icon: Icons.schedule_rounded,
                          iconColor: Colors.blue,
                          title: 'المنطقة الزمنية للمنظومة',
                          subtitle: '${context.tr('التوقيت المعتمد لحساب الحصص والمواعيد')}: $_timeZone',
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: () => _pickTimeZone(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                  ],

                  // 3. Notifications & Alerts
                  if (_shouldShow(_SettingsCategory.notifications)) ...[
                    _SettingsGroup(
                      title: 'الإشعارات والتنبيهات الفورية',
                      icon: Icons.notifications_active_rounded,
                      accentColor: Colors.orange,
                      children: [
                        _SettingsSwitchTile(
                          icon: Icons.notifications_on_rounded,
                          iconColor: Colors.orange,
                          title: 'الإشعارات الفورية (Push Notifications)',
                          subtitle: 'استلام تنبيهات لحظية عند تسجيل الحضور أو إعلان الدرجات',
                          value: _pushNotifications,
                          onChanged: (val) {
                            _updateSetting(
                              'push_notifications',
                              val,
                              (v) => _pushNotifications = v,
                            );
                            if (val) {
                              pushService?.syncCurrentToken();
                            } else {
                              pushService?.unregisterCurrentToken();
                            }
                          },
                        ),
                        const Divider(height: 1),
                        _SettingsActionTile(
                          icon: Icons.notification_important_rounded,
                          iconColor: Colors.amber.shade700,
                          title: 'اختبار إرسال إشعار تجريبي فوري',
                          subtitle: 'إطلاق إشعار محلي وتنبيه صوتي للتأكد من وصول التنبيهات لجهازك',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.tr('تجربة الآن 🔔'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                          onTap: _sendTestNotification,
                        ),
                        const Divider(height: 1),
                        _SettingsSwitchTile(
                          icon: Icons.mark_email_read_rounded,
                          iconColor: Colors.amber.shade800,
                          title: 'النشرة والملخص اليومي',
                          subtitle: 'إرسال ملخص بالعمليات اليومية وحالات الغياب والتقارير',
                          value: _emailDigest,
                          onChanged: (val) => _updateSetting(
                            'email_digest',
                            val,
                            (v) => _emailDigest = v,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                  ],

                  // 4. Hardware & Printing (Thermal POS Printers)
                  if (_shouldShow(_SettingsCategory.hardware)) ...[
                    _SettingsGroup(
                      title: 'طابعات الإيصالات والعتاد (ESC / POS)',
                      icon: Icons.print_rounded,
                      accentColor: Colors.teal,
                      children: [
                        _SettingsActionTile(
                          icon: Icons.print_outlined,
                          iconColor: Colors.teal,
                          title: 'إعدادات طابعة الإيصالات الحرارية',
                          subtitle: 'ربط طابعات فواتير السنتر عبر USB / Bluetooth / الشبكة وطباعة إيصال فوري تجريبي',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.tr('تهيئة واختبار 🖨️'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                          onTap: _openPrinterSettings,
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.tr('يدعم النظام جميع طابعات الكاشير الحرارية القياسية (80mm و 58mm) مع دعم الباركود وفواتير الملازم والحصص.'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                  ],

                  // 5. Security & Privacy
                  if (_shouldShow(_SettingsCategory.security)) ...[
                    _SettingsGroup(
                      title: 'الأمان والخصوصية وحماية البيانات',
                      icon: Icons.security_rounded,
                      accentColor: AppColors.success,
                      children: [
                        _SettingsSwitchTile(
                          icon: Icons.fingerprint_rounded,
                          iconColor: AppColors.success,
                          title: 'قفل التطبيق بالبصمة / Face ID',
                          subtitle: 'طلب التحقق الحيوي عند فتح التطبيق لحماية الخصوصية والدرجات',
                          value: _biometricLogin,
                          onChanged: (val) async {
                            if (val) {
                              final localAuth = LocalAuthentication();
                              try {
                                final canCheck = await localAuth.canCheckBiometrics;
                                final isSupported = await localAuth.isDeviceSupported();
                                if (canCheck || isSupported) {
                                  final didAuth = await localAuth.authenticate(
                                    localizedReason: 'يرجى تأكيد الهوية لتفعيل القفل بالبصمة',
                                  );
                                  if (didAuth) {
                                    _updateSetting(
                                      'biometric_login',
                                      true,
                                      (v) => _biometricLogin = v,
                                    );
                                    _showSnackBar('تم تفعيل القفل الحيوي بالبصمة بنجاح 🔒');
                                  }
                                } else {
                                  if (mounted) {
                                    _showSnackBar(
                                      'جهازك لا يدعم مستشعر البصمة أو لم يتم تعيين قفل للجهاز.',
                                      isError: true,
                                    );
                                  }
                                }
                              } on PlatformException {
                                if (mounted) {
                                  _showSnackBar(
                                    'تعذر الوصول لمستشعر البصمة. يرجى تفعيل رمز القفل في إعدادات الهاتف.',
                                    isError: true,
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  _showSnackBar('خطأ في البصمة: $e', isError: true);
                                }
                              }
                            } else {
                              _updateSetting(
                                'biometric_login',
                                false,
                                (v) => _biometricLogin = v,
                              );
                              _showSnackBar('تم تعطيل القفل بالبصمة');
                            }
                          },
                        ),
                        const Divider(height: 1),
                        _SettingsSwitchTile(
                          icon: Icons.verified_user_rounded,
                          iconColor: Colors.teal,
                          title: 'المصادقة الثنائية (2FA)',
                          subtitle: 'إلزام التحقق بخطوتين عند تسجيل الدخول لحسابات السنتر',
                          value: _twoFactorAuth,
                          onChanged: (val) => _updateSetting(
                            'two_factor_auth',
                            val,
                            (v) => _twoFactorAuth = v,
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsSwitchTile(
                          icon: Icons.analytics_outlined,
                          iconColor: Colors.blueGrey,
                          title: 'تحسين تجربة الاستخدام واستقرار النظام',
                          subtitle: 'إرسال تقارير أداء مجهولة لتسريع النظام ومنع الأعطال',
                          value: _dataCollection,
                          onChanged: (val) => _updateSetting(
                            'data_collection',
                            val,
                            (v) => _dataCollection = v,
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsActionTile(
                          icon: Icons.lock_reset_rounded,
                          iconColor: Colors.indigo,
                          title: 'تغيير كلمة المرور للحساب',
                          subtitle: 'تحديث كلمة المرور لحماية الحساب ومزامنتها على السحابة',
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: _openChangePasswordDialog,
                        ),
                        const Divider(height: 1),
                        _SettingsActionTile(
                          icon: Icons.privacy_tip_rounded,
                          iconColor: Colors.indigo,
                          title: 'سياسة الخصوصية وشروط الخدمة',
                          subtitle: 'الاطلاع على بنود حماية بيانات الطلاب والتراخيص الأكاديمية',
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: () => PrivacyAndTermsScreen.show(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                  ],

                  // 6. Storage & System Health
                  if (_shouldShow(_SettingsCategory.system)) ...[
                    _SettingsGroup(
                      title: 'صيانة المنظومة وسرعة الاستجابة',
                      icon: Icons.cleaning_services_rounded,
                      accentColor: Colors.cyan,
                      children: [
                        _SettingsActionTile(
                          icon: Icons.cloud_sync_rounded,
                          iconColor: Colors.blue,
                          title: 'فحص الاتصال بالسحابة (Ping Test)',
                          subtitle: _lastPingMs != null
                              ? '${context.tr('زمن الاستجابة')}: $_lastPingMs ms • ${context.tr('متصل ومستقر ⚡')}'
                              : context.tr('التحقق من جودة الاتصال بقاعدة بيانات السنتر السحابية'),
                          trailing: _isTestingPing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : OutlinedButton(
                                  onPressed: _testCloudPing,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(context.tr('فحص ⚡'), style: const TextStyle(fontSize: 12)),
                                ),
                          onTap: _testCloudPing,
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 420;
                              final info = Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.cyan.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.storage_rounded, color: Colors.cyan, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('تفريغ الذاكرة المؤقتة (Clear Cache)'),
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          context.tr('إزالة الصور المؤقتة وملفات التخزين لتسريع التطبيق وحل أي بطء'),
                                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );

                              final button = _isClearingCache
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.5),
                                    )
                                  : OutlinedButton(
                                      onPressed: _clearCache,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: Text(context.tr('تنظيف 🧹'), style: const TextStyle(fontSize: 12)),
                                    );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    info,
                                    const SizedBox(height: 10),
                                    Align(alignment: AlignmentDirectional.centerEnd, child: button),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: info),
                                  const SizedBox(width: 8),
                                  button,
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 7. Technical Support & Assistance
                    _SettingsGroup(
                      title: 'المساعدة والدعم الفني المباشر',
                      icon: Icons.support_agent_rounded,
                      accentColor: Colors.green,
                      children: [
                        _SettingsActionTile(
                          icon: Icons.chat_rounded,
                          iconColor: Colors.green,
                          title: 'مراسلة الدعم الفني عبر واتساب',
                          subtitle: 'تواصل مباشر مع فريق الدعم للمساعدة الفورية أو الاستفسارات',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.tr('واتساب 💬'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          onTap: _launchSupportWhatsApp,
                        ),
                        const Divider(height: 1),
                        _SettingsActionTile(
                          icon: Icons.copy_all_rounded,
                          iconColor: Colors.blueGrey,
                          title: 'نسخ بيانات التشخيص للدعم الفني',
                          subtitle: 'نسخ معلومات الحساب وإصدار التطبيق لتقديمها عند طلب المساعدة',
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: _copyDiagnosticInfo,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                  ],

                  // 8. System Info & Account Operations
                  if (_shouldShow(_SettingsCategory.account) || _shouldShow(_SettingsCategory.system)) ...[
                    _SettingsGroup(
                      title: 'معلومات الحساب والمنظومة',
                      icon: Icons.info_outline_rounded,
                      accentColor: primaryColor,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 460;
                              final info = Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.school_rounded,
                                      color: AppColors.primary,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('منظومة بريفيو لإدارة المراكز التعليمية • Brivio LMS'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isNarrow ? 13.5 : 14.5,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          context.tr('الإصدار 2.5.0 (Build 850) • متصل بالسحابة'),
                                          style: TextStyle(
                                            fontSize: isNarrow ? 11 : 12,
                                            color: isDark ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );

                              final badge = Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  context.tr('مستقر ✔️'),
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    info,
                                    const SizedBox(height: 8),
                                    Align(alignment: AlignmentDirectional.centerEnd, child: badge),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: info),
                                  const SizedBox(width: 8),
                                  badge,
                                ],
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsActionTile(
                          icon: Icons.logout_rounded,
                          iconColor: Colors.deepOrange,
                          title: 'تسجيل الخروج من الحساب',
                          subtitle: 'الخروج الآمن والعودة لشاشة تسجيل الدخول',
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.deepOrange),
                          onTap: _confirmSignOut,
                        ),
                        const Divider(height: 1),
                        _SettingsActionTile(
                          icon: Icons.delete_forever_rounded,
                          iconColor: Colors.red,
                          title: 'حذف الحساب نهائياً',
                          subtitle: 'إزالة بيانات الدخول والملف الشخصي نهائياً من النظام',
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Colors.red,
                          ),
                          onTap: _confirmAccountDeletion,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _shouldShow(_SettingsCategory category) {
    if (_selectedCategory == _SettingsCategory.all) return true;
    return _selectedCategory == category;
  }

  Widget _buildCategoryChips(bool isDark) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _SettingsCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _SettingsCategory.values[index];
          final isSelected = _selectedCategory == cat;
          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = cat);
            },
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat.icon,
                    size: 16,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr(cat.label),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserProfileCard(bool isDark, Color primary) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [AppColors.primary.withValues(alpha: 0.08), Colors.white],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EditableAvatar(
                    avatarUrl: _avatarUrl,
                    fullName: _userName ?? 'مستخدم المنظومة',
                    role: _userRole,
                    userId: Supabase.instance.client.auth.currentUser?.id,
                    userEmail: _userEmail,
                    radius: isNarrow ? 26 : 30,
                    onAvatarChanged: (newUrl) {
                      setState(() {
                        _avatarUrl = newUrl;
                      });
                    },
                  ),
                  SizedBox(width: isNarrow ? 10 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _userName ?? 'مستخدم المنظومة',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isNarrow ? 15 : 16.5,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (_lastPingMs != null || !_isTestingPing)
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: (_lastPingMs != null || !_isTestingPing)
                                          ? AppColors.success
                                          : Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _lastPingMs != null ? '$_lastPingMs ms' : context.tr('متصل'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: (_lastPingMs != null || !_isTestingPing)
                                          ? AppColors.success
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _userEmail ?? context.tr('غير مسجل بريد إلكتروني'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        if (_userPhone != null && _userPhone!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '📞 $_userPhone',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _formatRole(_userRole),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              // Quick Action Buttons
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openEditProfileDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : AppColors.primary.withValues(alpha: 0.35),
                        ),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, inherit: true),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(context.tr('تعديل البيانات')),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _openChangePasswordDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : AppColors.primary.withValues(alpha: 0.35),
                        ),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, inherit: true),
                      ),
                      icon: const Icon(Icons.lock_reset_rounded, size: 16),
                      label: Text(context.tr('تغيير كلمة المرور')),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openEditProfileDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : AppColors.primary.withValues(alpha: 0.35),
                          ),
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, inherit: true),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(context.tr('تعديل البيانات')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openChangePasswordDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : AppColors.primary.withValues(alpha: 0.35),
                          ),
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, inherit: true),
                        ),
                        icon: const Icon(Icons.lock_reset_rounded, size: 16),
                        label: Text(context.tr('تغيير كلمة المرور')),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  const _SettingsGroup({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              context.tr(title),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _ThemeSelectCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeSelectCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.25 : 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primary
                : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? primary : (isDark ? Colors.white70 : Colors.black54),
              size: 24,
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                context.tr(label),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12.5,
                  color: isSelected ? primary : null,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                context.tr(subtitle),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String flag;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.flag,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.25 : 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? primary : null,
                  ),
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle_rounded, size: 15, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(title),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr(subtitle),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: iconColor,
          ),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(title),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.tr(subtitle),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
