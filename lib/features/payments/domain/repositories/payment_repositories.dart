import '../models/payment_models.dart';

abstract class ISubscriptionPlanRepository {
  Future<List<SubscriptionPlan>> fetchPlans();
  Future<SubscriptionPlan> createPlan(SubscriptionPlan plan);
}

abstract class IInvoiceRepository {
  Future<List<Invoice>> fetchInvoicesForStudent(String studentId);
  Future<Invoice> fetchInvoiceById(String invoiceId);
  Future<void> rescheduleDueDate({
    required String invoiceId,
    required DateTime newDueAt,
    String? reason,
  });
}

abstract class IPaymentRepository {
  Future<PaymentAttempt> createPaymentIntent({
    required String invoiceId,
    required String provider,
    required String idempotencyKey,
  });
  Future<void> recordManualPayment({
    required String invoiceId,
    required int amountMinor,
    String paymentMethod = 'cash',
    String? notes,
  });
  Future<FinancialSummary> fetchStudentFinancialSummary(String studentId);
  Future<SystemFinancialSummary> fetchSystemFinancialSummary();
  Future<Map<String, dynamic>> generateMonthlyBillingCycle({
    DateTime? billingMonth,
    int dueDays = 7,
    String? centerId,
  });
}

abstract class IReceiptRepository {
  Future<List<Receipt>> fetchReceiptsForStudent(String studentId);
}
