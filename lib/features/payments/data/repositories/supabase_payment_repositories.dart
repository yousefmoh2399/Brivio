import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/payment_models.dart';
import '../../domain/repositories/payment_repositories.dart';

class SupabaseSubscriptionPlanRepository
    implements ISubscriptionPlanRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseSubscriptionPlanRepository(this._wrapper);

  @override
  Future<List<SubscriptionPlan>> fetchPlans() async {
    try {
      final response = await _wrapper.client
          .from('subscription_plans')
          .select()
          .eq('status', 'active')
          .order('total_amount_minor');
      return (response as List)
          .map((j) => SubscriptionPlan.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch subscription plans: ${e.toString()}',
      );
    }
  }

  @override
  Future<SubscriptionPlan> createPlan(SubscriptionPlan plan) async {
    try {
      final response = await _wrapper.client
          .from('subscription_plans')
          .insert({
            'name': plan.name,
            'description': plan.description,
            'billing_type': plan.billingType,
            'total_amount_minor': plan.totalAmountMinor,
            'currency': plan.currency,
            'installment_count': plan.installmentCount,
            'status': plan.status,
          })
          .select()
          .single();
      return SubscriptionPlan.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create subscription plan: ${e.toString()}',
      );
    }
  }
}

class SupabaseInvoiceRepository implements IInvoiceRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseInvoiceRepository(this._wrapper);

  @override
  Future<List<Invoice>> fetchInvoicesForStudent(String studentId) async {
    try {
      final response = await _wrapper.withFreshSession(
        (client) => client
            .from('invoices')
            .select()
            .eq('student_id', studentId)
            .order('issued_at', ascending: false),
      );
      return (response as List)
          .map((j) => Invoice.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch invoices: ${e.toString()}',
      );
    }
  }

  @override
  Future<Invoice> fetchInvoiceById(String invoiceId) async {
    try {
      final response = await _wrapper.withFreshSession(
        (client) =>
            client.from('invoices').select().eq('id', invoiceId).single(),
      );
      return Invoice.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch invoice details: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> rescheduleDueDate({
    required String invoiceId,
    required DateTime newDueAt,
    String? reason,
  }) async {
    try {
      try {
        final res = await _wrapper.client.rpc(
          'reschedule_invoice_due_date',
          params: {
            'p_invoice_id': invoiceId,
            'p_new_due_at': newDueAt.toIso8601String(),
            'p_reason': reason,
          },
        );
        if (res is Map && res['success'] == true) return;
      } catch (_) {
        // Fallback to direct table update if RPC is not present
        await _wrapper.client.from('invoices').update({
          'due_at': newDueAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', invoiceId);
      }
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to reschedule invoice due date: ${e.toString()}',
      );
    }
  }
}

class SupabasePaymentRepository implements IPaymentRepository {
  final SupabaseClientWrapper _wrapper;
  SupabasePaymentRepository(this._wrapper);

  @override
  Future<PaymentAttempt> createPaymentIntent({
    required String invoiceId,
    required String provider,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'create_payment_intent',
        params: {
          'p_invoice_id': invoiceId,
          'p_provider': provider,
          'p_idempotency_key': idempotencyKey,
        },
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(
          message: 'Create payment intent operation failed',
        );
      }

      final attemptId = jsonMap['attempt_id'] as String;
      final attRes = await _wrapper.client
          .from('payment_attempts')
          .select()
          .eq('id', attemptId)
          .single();

      return PaymentAttempt.fromJson(attRes);
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Create payment intent failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> recordManualPayment({
    required String invoiceId,
    required int amountMinor,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    try {
      final response = await _wrapper.withFreshSession(
        (client) => client.rpc(
          'record_manual_payment',
          params: {
            'p_invoice_id': invoiceId,
            'p_amount_minor': amountMinor,
            'p_payment_method': paymentMethod,
            'p_notes': notes,
          },
        ),
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(
          message: 'Record manual payment operation failed',
        );
      }
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Record manual payment failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<FinancialSummary> fetchStudentFinancialSummary(
    String studentId,
  ) async {
    try {
      final response = await _wrapper.client.rpc(
        'get_student_financial_summary',
        params: {'p_student_id': studentId},
      );

      return FinancialSummary.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (_) {
      // Fallback: compute from receipts and invoices
      int totalPaidMinor = 0;
      int totalOutstandingMinor = 0;
      int pendingCount = 0;

      try {
        final receiptsRes = await _wrapper.client
            .from('receipts')
            .select('amount_minor')
            .eq('student_id', studentId);
        for (final row in receiptsRes) {
          final amt = (row['amount_minor'] as num?)?.toInt() ?? 0;
          totalPaidMinor += amt;
        }
      } catch (_) {}

      try {
        final invoicesRes = await _wrapper.client
            .from('invoices')
            .select('total_minor, amount_paid_minor, status')
            .eq('student_id', studentId);
        for (final row in invoicesRes) {
          final status = row['status']?.toString().toLowerCase();
          final total = (row['total_minor'] as num?)?.toInt() ?? 0;
          final paid = (row['amount_paid_minor'] as num?)?.toInt() ?? 0;
          final diff = total - paid;
          if (status == 'pending' ||
              status == 'unpaid' ||
              status == 'overdue' ||
              status == 'issued' ||
              status == 'partially_paid') {
            totalOutstandingMinor += (diff > 0 ? diff : total);
            pendingCount++;
          }
        }
      } catch (_) {}

      return FinancialSummary(
        studentId: studentId,
        invoiceCount: pendingCount,
        totalDueMinor: totalPaidMinor + totalOutstandingMinor,
        totalPaidMinor: totalPaidMinor,
        remainingBalanceMinor: totalOutstandingMinor,
        currency: 'EGP',
      );
    }
  }

  @override
  Future<SystemFinancialSummary> fetchSystemFinancialSummary() async {
    try {
      final response = await _wrapper.client.rpc('get_financial_summary');
      final listResponse = response as List;
      if (listResponse.isNotEmpty) {
        return SystemFinancialSummary.fromJson(
          Map<String, dynamic>.from(listResponse.first as Map),
        );
      }
    } catch (_) {}

    // Fallback: compute directly from receipts and invoices
    int totalCollectedMinor = 0;
    int totalOutstandingMinor = 0;

    try {
      final receiptsRes =
          await _wrapper.client.from('receipts').select('amount_minor');
      for (final row in receiptsRes) {
        final amt = (row['amount_minor'] as num?)?.toInt() ?? 0;
        totalCollectedMinor += amt;
      }
    } catch (_) {}

    try {
      final salesRes =
          await _wrapper.client.from('bookstore_sales').select('total_amount');
      for (final row in salesRes) {
        final amt = ((row['total_amount'] as num?)?.toDouble() ?? 0.0) * 100;
        totalCollectedMinor += amt.toInt();
      }
    } catch (_) {}

    try {
      final invoicesRes =
          await _wrapper.client.from('invoices').select('total_minor, amount_paid_minor, status');
      for (final row in invoicesRes) {
        final status = row['status']?.toString().toLowerCase();
        final total = (row['total_minor'] as num?)?.toInt() ?? 0;
        final paid = (row['amount_paid_minor'] as num?)?.toInt() ?? 0;
        final diff = total - paid;
        if (status == 'pending' ||
            status == 'unpaid' ||
            status == 'overdue' ||
            status == 'issued' ||
            status == 'partially_paid') {
          totalOutstandingMinor += (diff > 0 ? diff : total);
        }
      }
    } catch (_) {}

    return SystemFinancialSummary(
      totalOutstandingMinor: totalOutstandingMinor,
      totalCollectedMinor: totalCollectedMinor,
      expectedMonthlyRevenueMinor:
          totalCollectedMinor + totalOutstandingMinor,
      totalAdjustmentsMinor: 0,
    );
  }

  @override
  Future<Map<String, dynamic>> generateMonthlyBillingCycle({
    DateTime? billingMonth,
    int dueDays = 7,
    String? centerId,
  }) async {
    try {
      final targetMonth = billingMonth ?? DateTime.now();
      final monthStr =
          '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01';

      try {
        final res = await _wrapper.client.rpc(
          'generate_monthly_billing_cycle',
          params: {
            'p_billing_month': monthStr,
            'p_due_days': dueDays,
            if (centerId != null) 'p_center_id': centerId,
          },
        );
        if (res is Map && res['success'] == true) {
          return Map<String, dynamic>.from(res);
        }
      } catch (_) {
        // Fallback: Dart-driven monthly invoice generator for active enrollments
        final enrollments = await _wrapper.client
            .from('enrollments')
            .select('id, student_id, group_id, base_price_minor, discount_minor, final_price_minor, groups(name)')
            .eq('status', 'active');

        int createdCount = 0;
        int totalMinor = 0;
        final dueDate = targetMonth.add(Duration(days: dueDays));

        for (final e in (enrollments as List)) {
          final enrollmentId = e['id'].toString();
          final studentId = e['student_id'].toString();
          final groupId = e['group_id'].toString();
          final base = (e['base_price_minor'] as num?)?.toInt() ?? 0;
          final disc = (e['discount_minor'] as num?)?.toInt() ?? 0;
          final finalPrice =
              (e['final_price_minor'] as num?)?.toInt() ?? (base - disc);

          if (finalPrice <= 0) continue;

          // Check if invoice already issued this month
          final existing = await _wrapper.client
              .from('invoices')
              .select('id')
              .eq('enrollment_id', enrollmentId)
              .gte('issued_at', monthStr)
              .lt(
                'issued_at',
                '${targetMonth.month == 12 ? targetMonth.year + 1 : targetMonth.year}-${(targetMonth.month % 12 + 1).toString().padLeft(2, '0')}-01',
              )
              .neq('status', 'cancelled')
              .maybeSingle();

          if (existing != null) continue;

          final invRes = await _wrapper.client.from('invoices').insert({
            'student_id': studentId,
            'enrollment_id': enrollmentId,
            'group_id': groupId,
            'currency': 'EGP',
            'subtotal_minor': base > 0 ? base : finalPrice,
            'discount_minor': disc,
            'total_minor': finalPrice,
            'amount_paid_minor': 0,
            'status': 'issued',
            'issued_at': monthStr,
            'due_at': dueDate.toIso8601String(),
          }).select('id').single();

          final invId = invRes['id'].toString();
          final groupName =
              (e['groups'] as Map?)?['name']?.toString() ?? 'مجموعة دراسية';

          await _wrapper.client.from('invoice_items').insert({
            'invoice_id': invId,
            'description':
                'مصروفات شهر ${targetMonth.month}/${targetMonth.year} - $groupName',
            'quantity': 1,
            'unit_amount_minor': finalPrice,
            'total_minor': finalPrice,
          });

          createdCount++;
          totalMinor += finalPrice;
        }

        return {
          'success': true,
          'invoices_created': createdCount,
          'total_amount_minor': totalMinor,
          'month': '${targetMonth.month}/${targetMonth.year}',
        };
      }
      return {'success': false, 'message': 'Unknown response'};
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to generate monthly billing cycle: ${e.toString()}',
      );
    }
  }
}

class SupabaseReceiptRepository implements IReceiptRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseReceiptRepository(this._wrapper);

  @override
  Future<List<Receipt>> fetchReceiptsForStudent(String studentId) async {
    try {
      final response = await _wrapper.withFreshSession(
        (client) => client
            .from('receipts')
            .select()
            .eq('student_id', studentId)
            .order('issued_at', ascending: false),
      );
      return (response as List)
          .map((j) => Receipt.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch receipts: ${e.toString()}',
      );
    }
  }
}
