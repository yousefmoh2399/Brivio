class SubscriptionPlan {
  final String id;
  final String name;
  final String? description;
  final String billingType;
  final int totalAmountMinor;
  final String currency;
  final int installmentCount;
  final String status;

  SubscriptionPlan({
    required this.id,
    required this.name,
    this.description,
    required this.billingType,
    required this.totalAmountMinor,
    this.currency = 'EGP',
    this.installmentCount = 1,
    this.status = 'active',
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      billingType: json['billing_type'] as String? ?? 'one_time',
      totalAmountMinor: json['total_amount_minor'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'EGP',
      installmentCount: json['installment_count'] as int? ?? 1,
      status: json['status'] as String? ?? 'active',
    );
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String studentId;
  final String? subscriptionId;
  final String currency;
  final int subtotalMinor;
  final int discountMinor;
  final int totalMinor;
  final int amountPaidMinor;
  final String status;
  final DateTime dueAt;
  final DateTime issuedAt;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.studentId,
    this.subscriptionId,
    this.currency = 'EGP',
    required this.subtotalMinor,
    this.discountMinor = 0,
    required this.totalMinor,
    this.amountPaidMinor = 0,
    required this.status,
    required this.dueAt,
    required this.issuedAt,
  });

  int get remainingBalanceMinor => totalMinor - amountPaidMinor;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      subscriptionId: json['subscription_id']?.toString(),
      currency: json['currency']?.toString() ?? 'EGP',
      subtotalMinor: (json['subtotal_minor'] as num?)?.toInt() ?? 0,
      discountMinor: (json['discount_minor'] as num?)?.toInt() ?? 0,
      totalMinor: (json['total_minor'] as num?)?.toInt() ?? 0,
      amountPaidMinor: (json['amount_paid_minor'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'issued',
      dueAt:
          DateTime.tryParse(json['due_at']?.toString() ?? '') ?? DateTime.now(),
      issuedAt:
          DateTime.tryParse(json['issued_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class PaymentAttempt {
  final String id;
  final String invoiceId;
  final String provider;
  final String? providerReference;
  final int amountMinor;
  final String currency;
  final String status;
  final String idempotencyKey;

  PaymentAttempt({
    required this.id,
    required this.invoiceId,
    required this.provider,
    this.providerReference,
    required this.amountMinor,
    this.currency = 'EGP',
    required this.status,
    required this.idempotencyKey,
  });

  factory PaymentAttempt.fromJson(Map<String, dynamic> json) {
    return PaymentAttempt(
      id: json['id']?.toString() ?? '',
      invoiceId: json['invoice_id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'cash',
      providerReference: json['provider_reference']?.toString(),
      amountMinor: (json['amount_minor'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'EGP',
      status: json['status']?.toString() ?? 'pending',
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
    );
  }
}

class Receipt {
  final String id;
  final String receiptNumber;
  final String transactionId;
  final String invoiceId;
  final String studentId;
  final int amountMinor;
  final String currency;
  final DateTime issuedAt;

  Receipt({
    required this.id,
    required this.receiptNumber,
    required this.transactionId,
    required this.invoiceId,
    required this.studentId,
    required this.amountMinor,
    this.currency = 'EGP',
    required this.issuedAt,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id']?.toString() ?? '',
      receiptNumber: json['receipt_number']?.toString() ?? '',
      transactionId: json['transaction_id']?.toString() ?? '',
      invoiceId: json['invoice_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      amountMinor: (json['amount_minor'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'EGP',
      issuedAt:
          DateTime.tryParse(json['issued_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class FinancialSummary {
  final String studentId;
  final int invoiceCount;
  final int totalDueMinor;
  final int totalPaidMinor;
  final int remainingBalanceMinor;
  final String currency;

  FinancialSummary({
    required this.studentId,
    required this.invoiceCount,
    required this.totalDueMinor,
    required this.totalPaidMinor,
    required this.remainingBalanceMinor,
    this.currency = 'EGP',
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    return FinancialSummary(
      studentId: json['student_id'] as String? ?? '',
      invoiceCount: json['invoice_count'] as int? ?? 0,
      totalDueMinor: json['total_due_minor'] as int? ?? 0,
      totalPaidMinor: json['total_paid_minor'] as int? ?? 0,
      remainingBalanceMinor: json['remaining_balance_minor'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'EGP',
    );
  }
}

class SystemFinancialSummary {
  final int totalOutstandingMinor;
  final int totalCollectedMinor;
  final int expectedMonthlyRevenueMinor;
  final int totalAdjustmentsMinor;

  SystemFinancialSummary({
    required this.totalOutstandingMinor,
    required this.totalCollectedMinor,
    required this.expectedMonthlyRevenueMinor,
    required this.totalAdjustmentsMinor,
  });

  factory SystemFinancialSummary.fromJson(Map<String, dynamic> json) {
    return SystemFinancialSummary(
      totalOutstandingMinor: json['total_outstanding_minor'] as int? ?? 0,
      totalCollectedMinor: json['total_collected_minor'] as int? ?? 0,
      expectedMonthlyRevenueMinor:
          json['expected_monthly_revenue_minor'] as int? ?? 0,
      totalAdjustmentsMinor: json['total_adjustments_minor'] as int? ?? 0,
    );
  }
}
