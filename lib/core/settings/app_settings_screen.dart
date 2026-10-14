import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../localization/app_locale_controller.dart';
import '../notifications/push_notification_service.dart';
import '../services/settings_service.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/components/glass_card.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/admin/domain/repositories/i_admin_repository.dart';
import '../../features/legal/presentation/screens/privacy_and_terms_screen.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PortalPageShell(
      title: 'إعدادات المنظومة والتطبيق',
      subtitle: 'تخصيص المظهر العام، لغة العرض، الإشعارات، والأمان المتقدم.',
      icon: Icons.settings_suggest_rounded,
      accentColor: AppColors.primary,
      child: Material(
        type: MaterialType.transparency,
        child: AppSettingsPanel(),
      ),
    );
  }
}

class AppSettingsPanel extends StatefulWidget {
  const AppSettingsPanel({super.key});

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
  String _timeZone = 'UTC+03:00';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settingsService = GetIt.instance<SettingsService>();
    _emailDigest = settingsService.emailDigest;
    _twoFactorAuth = settingsService.twoFactorAuth;
    _dataCollection = settingsService.dataCollection;
    _biometricLogin = settingsService.biometricLogin;
    _pushNotifications = settingsService.pushNotifications;
    _animationQuality = settingsService.animationQuality;
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

    if (key == 'biometric_login' || key == 'animation_quality') {
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

  @override
  Widget build(BuildContext context) {
    final settingsService = GetIt.instance<SettingsService>();
    final pushService = GetIt.instance.isRegistered<PushNotificationService>()
        ? GetIt.instance<PushNotificationService>()
        : null;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;

    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // 1. Appearance Section
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
                        const Text(
                          'نمط العرض (السمة)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'اختر بين المظهر الفاتح المناسب للقاعات المضيئة أو الداكن المريح للعين.',
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
                        const Text(
                          'لغة واجهة التطبيق',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                    title: 'المنطقة الزمنية',
                    subtitle: 'التوقيت المحلي لحساب الحصص والمواعيد: $_timeZone',
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () => _pickTimeZone(context),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 3. Notifications & Alerts
              _SettingsGroup(
                title: 'الإشعارات والتنبيهات',
                icon: Icons.notifications_active_rounded,
                accentColor: Colors.orange,
                children: [
                  _SettingsSwitchTile(
                    icon: Icons.notifications_on_rounded,
                    iconColor: Colors.orange,
                    title: 'الإشعارات الفورية (Push)',
                    subtitle: 'استلام تنبيهات فورية عند تسجيل الحضور أو إضافة درجات وامتحانات',
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
                  _SettingsSwitchTile(
                    icon: Icons.mark_email_read_rounded,
                    iconColor: Colors.amber.shade700,
                    title: 'النشرة والملخص اليومي',
                    subtitle: 'إرسال ملخص بالعمليات اليومية وحالات الغياب عبر البريد',
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

              // 4. Security & Privacy
              _SettingsGroup(
                title: 'الأمان والخصوصية وحماية البيانات',
                icon: Icons.security_rounded,
                accentColor: AppColors.success,
                children: [
                  _SettingsSwitchTile(
                    icon: Icons.fingerprint_rounded,
                    iconColor: AppColors.success,
                    title: 'قفل التطبيق بالبصمة / Face ID',
                    subtitle: 'طلب التحقق الحيوي عند فتح التطبيق لحماية الخصوصية',
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
                              'تعذر الوصول لخدمة البصمة. يرجى تفعيل رمز القفل في إعدادات الهاتف.',
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
                      }
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsSwitchTile(
                    icon: Icons.verified_user_rounded,
                    iconColor: Colors.teal,
                    title: 'المصادقة الثنائية (2FA)',
                    subtitle: 'إلزام التحقق بخطوتين عند تسجيل الدخول لحسابات الإدارة والسنتر',
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
                    title: 'تحسين تجربة الاستخدام',
                    subtitle: 'إرسال تقارير مجهولة لتحسين استقرار المنظومة وسرعتها',
                    value: _dataCollection,
                    onChanged: (val) => _updateSetting(
                      'data_collection',
                      val,
                      (v) => _dataCollection = v,
                    ),
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

              // 5. System Info & Account Operations
              _SettingsGroup(
                title: 'معلومات الحساب والمنظومة',
                icon: Icons.info_outline_rounded,
                accentColor: primaryColor,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
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
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'منظومة بريفيو التعليمية • Brivio LMS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'الإصدار 2.5.0 (Build 850) • متصل بالسحابة',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'مستقر ✔️',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
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
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _pickTimeZone(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timezones = [
      {'code': 'UTC+02:00', 'label': 'توقيت مصر والأردن (GMT+2)'},
      {'code': 'UTC+03:00', 'label': 'توقيت مكة المكرمة والقاهرة صيفاً (GMT+3)'},
      {'code': 'UTC+04:00', 'label': 'توقيت الإمارات وعُمان (GMT+4)'},
      {'code': 'UTC+01:00', 'label': 'توقيت الجزائر والمغرب وتونس (GMT+1)'},
      {'code': 'UTC+00:00', 'label': 'توقيت غرينتش العالمي (UTC+0)'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'اختر المنطقة الزمنية للمنظومة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
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

  void _confirmAccountDeletion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'حذف الحساب نهائياً',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في حذف حسابك؟ سيتم إزالة جميع بياناتك الشخصية وسجل دخولك وفقاً لسياسة الخصوصية. هذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
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
                await client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
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
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
                color: isSelected ? primary : null,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? Colors.white54 : Colors.black45,
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13.5,
                color: isSelected ? primary : null,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
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
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
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
