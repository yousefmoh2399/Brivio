import 'package:flutter/foundation.dart';
import '../../../../core/di/injection.dart';
import '../../../admin/domain/models/admin_models.dart';
import '../../../admin/domain/repositories/i_admin_repository.dart';

class AdminAnalyticsViewModel extends ChangeNotifier {
  final IAdminRepository _adminRepository = getIt<IAdminRepository>();

  AdminAnalytics? _analytics;
  AdminAnalytics? get analytics => _analytics;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> loadAnalytics({DateTime? startDate, DateTime? endDate}) async {
    if (_isDisposed) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final res = await _adminRepository.getAnalytics(start, end);
      if (!_isDisposed) {
        _analytics = res;
      }
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = 'تعذر تحميل بيانات التحليلات: $e';
      }
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
