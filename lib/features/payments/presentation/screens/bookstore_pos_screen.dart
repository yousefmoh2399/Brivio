import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../core/services/thermal_printer_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../widgets/thermal_printer_settings_dialog.dart';

class BookstorePosScreen extends StatefulWidget {
  final String? centerName;
  final String? cashierName;

  const BookstorePosScreen({
    super.key,
    this.centerName,
    this.cashierName,
  });

  @override
  State<BookstorePosScreen> createState() => _BookstorePosScreenState();
}

class _BookstorePosScreenState extends State<BookstorePosScreen> {
  final _searchBookController = TextEditingController();

  String _centerName = 'المركز التعليمي';
  String _cashierName = 'مسؤول الخزينة والمخزن';
  String? _centerId;

  // Real students loaded from Supabase
  List<Map<String, dynamic>> _students = [];
  Map<String, dynamic>? _selectedStudent;
  bool _isLoadingStudents = false;

  final List<Map<String, dynamic>> _inventory = [];
  bool _isLoadingInventory = false;

  final Map<String, int> _cart = {}; // bookId -> quantity
  bool _isProcessingSale = false;

  String get _cacheKey => 'bookstore_pos_inventory_${_centerId ?? 'local'}';

  @override
  void initState() {
    super.initState();
    if (widget.centerName != null && widget.centerName!.isNotEmpty) {
      _centerName = widget.centerName!;
    }
    if (widget.cashierName != null && widget.cashierName!.isNotEmpty) {
      _cashierName = widget.cashierName!;
    }
    ThermalPrinterService().init();
    _initData();
  }

  Future<void> _initData() async {
    await _loadCenterInfo();
    await Future.wait([
      _loadStudents(),
      _loadInventory(),
    ]);
  }

  Future<void> _loadCenterInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, center_id')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          final fullName = profile['full_name'] as String?;
          if (fullName != null && fullName.isNotEmpty && widget.cashierName == null) {
            _cashierName = fullName;
          }
          final centerId = profile['center_id'];
          if (centerId != null) {
            _centerId = centerId.toString();
            if (widget.centerName == null) {
              final center = await Supabase.instance.client
                  .from('educational_centers')
                  .select('name')
                  .eq('id', centerId)
                  .maybeSingle();
              if (center != null && center['name'] != null) {
                _centerName = center['name'];
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveLocalInventory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_inventory);
      await prefs.setString(_cacheKey, jsonStr);
      await prefs.setString('bookstore_pos_inventory_local', jsonStr);
    } catch (_) {}
  }

  Future<bool> _loadLocalInventory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString(_cacheKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        jsonStr = prefs.getString('bookstore_pos_inventory_local');
      }
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(
          (jsonDecode(jsonStr) as List).map((x) => Map<String, dynamic>.from(x as Map)),
        );
        if (list.isNotEmpty && mounted) {
          setState(() {
            _inventory.clear();
            _inventory.addAll(list);
          });
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _syncDeductedStockToRemote(String id, String title, int newStock) async {
    final nowStr = DateTime.now().toIso8601String();
    try {
      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id);
      if (isUuid) {
        await Supabase.instance.client.from('bookstore_items').update({
          'stock': newStock,
          'updated_at': nowStr,
        }).eq('id', id);
      } else {
        await Supabase.instance.client.from('bookstore_items').update({
          'stock': newStock,
          'updated_at': nowStr,
        }).eq('title', title);
      }
    } catch (e) {
      debugPrint('Error updating stock in remote DB: $e');
    }
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      var query = Supabase.instance.client
          .from('students')
          .select('id, student_code, profile:profiles!inner(full_name, phone_number, center_id)')
          .order('student_code');

      final res = await query;
      final List<Map<String, dynamic>> list = [];
      for (final s in (res as List<dynamic>)) {
        final profile = s['profile'] as Map<String, dynamic>? ?? {};
        if (_centerId != null) {
          final profileCenterId = profile['center_id']?.toString();
          if (profileCenterId != null && profileCenterId != _centerId) {
            continue;
          }
        }
        list.add({
          'id': s['id']?.toString() ?? '',
          'code': s['student_code']?.toString() ?? '',
          'name': profile['full_name']?.toString() ?? 'طالب',
          'phone': profile['phone_number']?.toString() ?? '',
        });
      }

      if (mounted) {
        setState(() {
          _students = list;
          _isLoadingStudents = false;
        });
      }
    } catch (_) {
      try {
        final res = await Supabase.instance.client
            .from('students')
            .select('id, student_code, profile:profiles(full_name, phone_number)')
            .order('student_code');

        final List<Map<String, dynamic>> list = [];
        for (final s in (res as List<dynamic>)) {
          final profile = s['profile'] as Map<String, dynamic>? ?? {};
          list.add({
            'id': s['id']?.toString() ?? '',
            'code': s['student_code']?.toString() ?? '',
            'name': profile['full_name']?.toString() ?? 'طالب',
            'phone': profile['phone_number']?.toString() ?? '',
          });
        }
        if (mounted) {
          setState(() {
            _students = list;
            _isLoadingStudents = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isLoadingStudents = false);
        }
      }
    }
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoadingInventory = _inventory.isEmpty);
    await _loadLocalInventory();

    try {
      var query = Supabase.instance.client
          .from('bookstore_items')
          .select('*')
          .eq('status', 'active');

      if (_centerId != null) {
        query = query.or('center_id.eq.$_centerId,center_id.is.null');
      }

      final rows = await query.order('created_at', ascending: false);

      final List<Map<String, dynamic>> items = [];
      for (final r in (rows as List<dynamic>)) {
        final rowMap = Map<String, dynamic>.from(r as Map);
        items.add({
          'id': rowMap['id'].toString(),
          'title': rowMap['title']?.toString() ?? '',
          'teacher': rowMap['teacher']?.toString() ?? 'السنتر',
          'price': (rowMap['price'] as num?)?.toDouble() ?? 40.0,
          'stock': (rowMap['stock'] as num?)?.toInt() ?? 0,
        });
      }

      if (items.isNotEmpty) {
        if (mounted) {
          // Merge with local inventory so stock deductions made on this device are strictly preserved!
          for (final item in items) {
            final localIndex = _inventory.indexWhere(
              (l) => l['id'] == item['id'] || l['title'] == item['title'],
            );
            if (localIndex != -1) {
              final localStock = (_inventory[localIndex]['stock'] as num?)?.toInt() ?? 0;
              // If local stock was deducted (lower than remote), prefer the deducted local stock
              if (localStock < (item['stock'] as int)) {
                item['stock'] = localStock;
                // Sync the deducted stock back to Supabase so remote database is updated
                _syncDeductedStockToRemote(item['id'].toString(), item['title'].toString(), localStock);
              }
            }
          }

          setState(() {
            _inventory.clear();
            _inventory.addAll(items);
            _isLoadingInventory = false;
          });
          await _saveLocalInventory();
        }
        return;
      }

      // If database table is empty for this center, seed from active subjects and persist
      if (_inventory.isEmpty) {
        List<dynamic> subjectsRes = [];
        try {
          var subQuery = Supabase.instance.client
              .from('subjects')
              .select('id, name')
              .eq('status', 'active');
          if (_centerId != null) {
            try {
              subjectsRes = await subQuery.eq('center_id', _centerId!);
            } catch (_) {
              // Fallback if subjects table doesn't have center_id column in database
              subjectsRes = await Supabase.instance.client
                  .from('subjects')
                  .select('id, name')
                  .eq('status', 'active');
            }
          } else {
            subjectsRes = await subQuery;
          }
        } catch (e) {
          debugPrint('Bookstore: subjects query error: $e');
        }

        final List<Map<String, dynamic>> seeded = [];
        for (final s in subjectsRes) {
          final title = 'ملزمة مادة ${s['name']}';
          final teacher = 'القسم الأكاديمي';
          final price = 40.0;
          final stock = 50;

          String generatedId = 'item-${DateTime.now().millisecondsSinceEpoch}-${s['id']}';
          try {
            final inserted = await Supabase.instance.client.from('bookstore_items').insert({
              'title': title,
              'teacher': teacher,
              'price': price,
              'stock': stock,
              'center_id': _centerId,
              'status': 'active',
            }).select('id').maybeSingle();
            if (inserted != null && inserted['id'] != null) {
              generatedId = inserted['id'].toString();
            }
          } catch (_) {}

          seeded.add({
            'id': generatedId,
            'title': title,
            'teacher': teacher,
            'price': price,
            'stock': stock,
          });
        }

        if (mounted) {
          setState(() {
            _inventory.clear();
            _inventory.addAll(seeded);
            _isLoadingInventory = false;
          });
          await _saveLocalInventory();
        }
      } else {
        if (mounted) setState(() => _isLoadingInventory = false);
      }
    } catch (e) {
      debugPrint('Error loading bookstore items from Supabase: $e');
      if (mounted) {
        setState(() => _isLoadingInventory = false);
      }
    }
  }

  void _addBookDialog() {
    final titleCtrl = TextEditingController();
    final teacherCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '40');
    final stockCtrl = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        title: const Row(
          children: [
            Icon(Icons.add_box_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('إضافة مذكرة / ملزمة جديدة للمخزن'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'اسم المذكرة أو الملزمة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: teacherCtrl,
                decoration: const InputDecoration(labelText: 'اسم الأستاذ / المادة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'سعر البيع (ج.م)', suffixText: 'ج.م', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية المتوفرة بالمخزن', suffixText: 'نسخة', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final teacher = teacherCtrl.text.trim().isEmpty ? 'السنتر' : teacherCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 40.0;
              final stock = int.tryParse(stockCtrl.text.trim()) ?? 30;
              if (title.isEmpty) return;

              String itemId = 'custom-${DateTime.now().millisecondsSinceEpoch}';
              try {
                final inserted = await Supabase.instance.client.from('bookstore_items').insert({
                  'title': title,
                  'teacher': teacher,
                  'price': price,
                  'stock': stock,
                  'center_id': _centerId,
                  'status': 'active',
                }).select('id').maybeSingle();
                if (inserted != null && inserted['id'] != null) {
                  itemId = inserted['id'].toString();
                }
              } catch (e) {
                debugPrint('Supabase insert bookstore item error: $e');
              }

              setState(() {
                _inventory.insert(0, {
                  'id': itemId,
                  'title': title,
                  'teacher': teacher,
                  'price': price,
                  'stock': stock,
                });
              });
              await _saveLocalInventory();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمت إضافة المذكرة إلى المخزن بنجاح 📚'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('إضافة وحفظ'),
          ),
        ],
      ),
    );
  }

  void _editBookDialog(Map<String, dynamic> item) {
    final titleCtrl = TextEditingController(text: item['title']?.toString() ?? '');
    final teacherCtrl = TextEditingController(text: item['teacher']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: item['price']?.toString() ?? '40');
    final stockCtrl = TextEditingController(text: item['stock']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('تعديل بيانات وسعر المذكرة والمخزن'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'اسم المذكرة أو الملزمة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: teacherCtrl,
                decoration: const InputDecoration(labelText: 'اسم الأستاذ / المادة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'سعر البيع (ج.م)', suffixText: 'ج.م', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية الحالية في المخزن', suffixText: 'نسخة', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final newTitle = titleCtrl.text.trim();
              final newTeacher = teacherCtrl.text.trim().isEmpty ? 'السنتر' : teacherCtrl.text.trim();
              final newPrice = double.tryParse(priceCtrl.text.trim()) ?? (item['price'] as double);
              final newStock = int.tryParse(stockCtrl.text.trim()) ?? (item['stock'] as int);
              if (newTitle.isEmpty) return;

              try {
                final isUuid = RegExp(
                  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                ).hasMatch(item['id']?.toString() ?? '');
                if (isUuid) {
                  await Supabase.instance.client.from('bookstore_items').update({
                    'title': newTitle,
                    'teacher': newTeacher,
                    'price': newPrice,
                    'stock': newStock,
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', item['id']);
                } else {
                  final updatedRows = await Supabase.instance.client.from('bookstore_items').update({
                    'title': newTitle,
                    'teacher': newTeacher,
                    'price': newPrice,
                    'stock': newStock,
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('title', item['title']).select('id');
                  if ((updatedRows as List).isEmpty) {
                    final inserted = await Supabase.instance.client.from('bookstore_items').insert({
                      'title': newTitle,
                      'teacher': newTeacher,
                      'price': newPrice,
                      'stock': newStock,
                      'center_id': _centerId,
                      'status': 'active',
                    }).select('id').maybeSingle();
                    if (inserted != null && inserted['id'] != null) {
                      item['id'] = inserted['id'].toString();
                    }
                  }
                }
              } catch (e) {
                debugPrint('Supabase update bookstore item error: $e');
              }

              setState(() {
                item['title'] = newTitle;
                item['teacher'] = newTeacher;
                item['price'] = newPrice;
                item['stock'] = newStock;
              });
              await _saveLocalInventory();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حفظ وتعديل بيانات المذكرة والمخزن بنجاح ✏️'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }

  void _deleteBookDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('تأكيد حذف المذكرة'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف مذكرة "${item['title']}" من المخزن نهائياً؟',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                final isUuid = RegExp(
                  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                ).hasMatch(item['id']?.toString() ?? '');
                if (isUuid) {
                  await Supabase.instance.client.from('bookstore_items').update({
                    'status': 'archived',
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', item['id']);
                } else {
                  await Supabase.instance.client.from('bookstore_items').update({
                    'status': 'archived',
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('title', item['title']);
                }
              } catch (_) {
                try {
                  final isUuid = RegExp(
                    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                  ).hasMatch(item['id']?.toString() ?? '');
                  if (isUuid) {
                    await Supabase.instance.client.from('bookstore_items').delete().eq('id', item['id']);
                  } else {
                    await Supabase.instance.client.from('bookstore_items').delete().eq('title', item['title']);
                  }
                } catch (_) {}
              }

              setState(() {
                _inventory.removeWhere((b) => b['id'] == item['id']);
                _cart.remove(item['id']);
              });
              await _saveLocalInventory();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف المذكرة من المخزن 🗑️')),
                );
              }
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchBookController.dispose();
    super.dispose();
  }

  double get _totalPrice {
    double total = 0.0;
    _cart.forEach((bookId, qty) {
      final item = _inventory.firstWhere((b) => b['id'] == bookId, orElse: () => {});
      if (item.isNotEmpty) {
        total += (item['price'] as double? ?? 0.0) * qty;
      }
    });
    return total;
  }

  void _addToCart(String bookId) {
    final item = _inventory.firstWhere((b) => b['id'] == bookId);
    final currentQty = _cart[bookId] ?? 0;
    if (currentQty >= (item['stock'] as int)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عذراً، نفدت الكمية المتاحة بالمخزن!')),
      );
      return;
    }
    setState(() {
      _cart[bookId] = currentQty + 1;
    });
  }

  void _removeFromCart(String bookId) {
    if (!_cart.containsKey(bookId)) return;
    final currentQty = _cart[bookId]!;
    setState(() {
      if (currentQty > 1) {
        _cart[bookId] = currentQty - 1;
      } else {
        _cart.remove(bookId);
      }
    });
  }

  Future<void> _completeCashSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة! برجاء اختيار المذكرات أولاً')),
      );
      return;
    }

    setState(() => _isProcessingSale = true);

    final receiptItems = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final nowStr = now.toIso8601String();

    // 1. Deduct quantity permanently in memory and database
    for (final entry in _cart.entries) {
      final bookId = entry.key;
      final qty = entry.value;
      final itemIndex = _inventory.indexWhere((b) => b['id'] == bookId);
      if (itemIndex != -1) {
        final item = _inventory[itemIndex];
        final oldStock = item['stock'] as int;
        final newStock = (oldStock - qty) < 0 ? 0 : (oldStock - qty);
        item['stock'] = newStock;

        receiptItems.add({
          'title': item['title'],
          'price': item['price'],
          'quantity': qty,
        });

        // Persist stock deduction to Supabase
        await _syncDeductedStockToRemote(bookId, item['title'].toString(), newStock);
      }
    }

    // Save updated stock to local persistent storage immediately
    await _saveLocalInventory();

    final receiptNumber = 'BK-${now.millisecondsSinceEpoch % 1000000}';
    final total = _totalPrice;

    final studentName = _selectedStudent != null
        ? _selectedStudent!['name']?.toString() ?? 'طالب نقدي'
        : 'طالب نقدي عام';
    final studentCode = _selectedStudent != null
        ? _selectedStudent!['code']?.toString() ?? 'GEN-CASH'
        : 'GEN-CASH';

    // 2. Persist to local cash register journal (guarantees money is NEVER lost even offline)
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString('pos_daily_sales_$todayKey');
      final List<dynamic> salesList = existingJson != null ? jsonDecode(existingJson) : [];
      salesList.add({
        'receipt_number': receiptNumber,
        'student_name': studentName,
        'student_code': studentCode,
        'total_amount': total,
        'cashier_name': _cashierName,
        'items': receiptItems,
        'created_at': nowStr,
        'center_id': _centerId,
      });
      await prefs.setString('pos_daily_sales_$todayKey', jsonEncode(salesList));
    } catch (_) {}

    // 3. Persist financial transaction to public.payment_transactions
    String? createdTxId;
    try {
      final txRow = await Supabase.instance.client.from('payment_transactions').insert({
        'amount': total,
        'amount_minor': (total * 100).toInt(),
        'currency': 'EGP',
        'transaction_type': 'payment',
        'provider': 'cash',
        'provider_transaction_id': 'BOOK-$receiptNumber',
        'status': 'completed',
        'occurred_at': nowStr,
      }).select('id').maybeSingle();
      if (txRow != null) {
        createdTxId = txRow['id']?.toString();
      }
    } catch (e) {
      debugPrint('Error inserting payment transaction: $e');
    }

    // 4. Persist financial collection to public.receipts
    try {
      final receiptData = <String, dynamic>{
        'receipt_number': receiptNumber,
        'amount': total,
        'amount_minor': (total * 100).toInt(),
        'currency': 'EGP',
        'payment_method': 'cash',
        'issued_at': nowStr,
      };
      if (_selectedStudent != null && _selectedStudent!['id'] != null) {
        receiptData['student_id'] = _selectedStudent!['id'];
      }
      if (_centerId != null) {
        receiptData['center_id'] = _centerId;
      }
      if (createdTxId != null) {
        receiptData['transaction_id'] = createdTxId;
      }
      await Supabase.instance.client.from('receipts').insert(receiptData);
    } catch (e) {
      debugPrint('Error inserting bookstore receipt: $e');
    }

    // 5. Log sales itemization to public.bookstore_sales
    try {
      final saleData = <String, dynamic>{
        'receipt_number': receiptNumber,
        'student_name': studentName,
        'student_code': studentCode,
        'total_amount': total,
        'cashier_name': _cashierName,
        'items': receiptItems,
        'created_at': nowStr,
      };
      if (_centerId != null) {
        saleData['center_id'] = _centerId;
      }
      if (_selectedStudent != null && _selectedStudent!['id'] != null) {
        saleData['student_id'] = _selectedStudent!['id'];
      }
      await Supabase.instance.client.from('bookstore_sales').insert(saleData);
    } catch (e) {
      debugPrint('Error inserting bookstore sale: $e');
    }

    // 6. Generate and print receipt PDF / ESC/POS
    final isDirectPrint = ThermalPrinterService().directPrintEnabled.value;
    try {
      final reportService = ReportGeneratorService();
      await reportService.generateBookstoreReceiptPdf(
        centerName: _centerName,
        receiptNumber: receiptNumber,
        studentName: studentName,
        studentCode: studentCode,
        cashierName: _cashierName,
        saleDate: now,
        items: receiptItems,
        totalAmount: total,
        printDirectly: isDirectPrint,
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isProcessingSale = false;
      _cart.clear();
      _selectedStudent = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
        content: Text('تم تحصيل $total ج.م نقداً وخصم المذكرات وتسجيل الإيصال #$receiptNumber في الخزينة بنجاح 💵✔️'),
      ),
    );
  }

  Future<void> _printBarcodeLabelsDialog([Map<String, dynamic>? singleItem]) async {
    final countCtrl = TextEditingController(text: '12');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('طباعة ملصقات الباركود للملازم 🏷️'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              singleItem != null
                  ? 'سيتم توليد ملصقات باركود حرارية لـ:\n${singleItem['title']}\nالسعر: ${singleItem['price']} ج.م'
                  : 'سيتم توليد شيت ملصقات باركود لكافة الملازم المسجلة بالمخزن (${_inventory.length} صنف)',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عدد الملصقات المطلوب طباعتها',
                suffixText: 'استيكر',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('طباعة الملصقات الآن'),
            onPressed: () async {
              Navigator.pop(ctx);
              final copies = int.tryParse(countCtrl.text.trim()) ?? 1;
              final itemsToPrint = singleItem != null ? [singleItem] : _inventory;
              try {
                await ReportGeneratorService().generateBookletBarcodeLabelsPdf(
                  centerName: _centerName,
                  items: itemsToPrint,
                  copiesPerItem: singleItem != null ? copies : 1,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم توليد شيت ملصقات الباركود بنجاح 🏷️'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل توليد ملصقات الباركود: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final filterText = _searchBookController.text.trim().toLowerCase();
    final filteredInventory = filterText.isEmpty
        ? _inventory
        : _inventory.where((b) => (b['title'] as String).toLowerCase().contains(filterText) || (b['teacher'] as String).toLowerCase().contains(filterText)).toList();

    final totalCartItems = _cart.values.fold<int>(0, (s, e) => s + e);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;

        final catalogPane = _buildCatalogPane(isDark, textPrimary, textSecondary, filteredInventory);
        final cartPane = _buildCartPane(isDark, textPrimary, textSecondary);

        Widget bodyContent;
        if (isNarrow) {
          bodyContent = TabBarView(
            children: [
              catalogPane,
              cartPane,
            ],
          );
        } else {
          bodyContent = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: catalogPane,
              ),
              Expanded(
                flex: 4,
                child: cartPane,
              ),
            ],
          );
        }

        final scaffold = Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            elevation: 0.5,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نظام بيع المذكرات والمخزن (POS) 📦', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('$_centerName • $_cashierName', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث بيانات المخزن',
                onPressed: _loadInventory,
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded),
                tooltip: 'طباعة ملصقات الباركود للمخزن 🏷️',
                onPressed: () => _printBarcodeLabelsDialog(),
              ),
              IconButton(
                icon: const Icon(Icons.print_rounded),
                tooltip: 'إعدادات الطابعة الحرارية (ESC/POS)',
                onPressed: () => ThermalPrinterSettingsDialog.show(context, centerName: _centerName),
              ),
            ],
            bottom: isNarrow
                ? TabBar(
                    tabs: [
                      const Tab(
                        icon: Icon(Icons.menu_book_rounded),
                        text: 'المذكرات والمخزن',
                      ),
                      Tab(
                        icon: Badge(
                          isLabelVisible: totalCartItems > 0,
                          label: Text('$totalCartItems'),
                          child: const Icon(Icons.shopping_cart_rounded),
                        ),
                        text: 'سلة البيع والفاتورة',
                      ),
                    ],
                  )
                : null,
          ),
          body: bodyContent,
        );

        if (isNarrow) {
          return DefaultTabController(
            length: 2,
            child: scaffold,
          );
        }
        return scaffold;
      },
    );
  }

  Widget _buildCatalogPane(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    List<Map<String, dynamic>> filteredInventory,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Student selector dropdown
          if (_isLoadingStudents)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _selectedStudent,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'الطالب المشتري (اختياري)',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('عميل نقدي عام / بدون تسجيل كود'),
                ),
                ..._students.map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text('${s['name']} (${s['code']})', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _selectedStudent = val),
            ),
          const SizedBox(height: 12),

          // Search and Add booklet
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchBookController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'ابحث باسم المذكرة أو الأستاذ...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة ملزمة'),
                onPressed: _addBookDialog,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Items grid/list
          Expanded(
            child: _isLoadingInventory
                ? const Center(child: CircularProgressIndicator())
                : filteredInventory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text(
                              'لا توجد مذكرات أو ملازم مسجلة بالمخزن',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'اضغط على زر (إضافة ملزمة) بالأعلى لإضافة ملزمة جديدة للبيع',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredInventory.length,
                        itemBuilder: (context, i) {
                          final item = filteredInventory[i];
                          final stock = item['stock'] as int;
                          final isLowStock = stock <= 10;
                          final inCartQty = _cart[item['id']] ?? 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _editBookDialog(item),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'],
                                          style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'المدرس: ${item['teacher']} • السعر: ${item['price']} ج.م',
                                          style: TextStyle(fontSize: 11, color: textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: stock == 0
                                                    ? Colors.grey.withValues(alpha: 0.2)
                                                    : (isLowStock ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15)),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                stock == 0
                                                    ? 'نفدت الكمية بالمخزن ❌'
                                                    : (isLowStock ? 'متبقي بالمخزن: $stock فقط ⚠️' : 'متوفر بالمخزن: $stock نسخة'),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: stock == 0
                                                      ? Colors.red
                                                      : (isLowStock ? Colors.red.shade800 : Colors.green.shade800),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Edit button
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.purple),
                                        tooltip: 'تعديل بيانات وسعر وكمية المذكرة ✏️',
                                        onPressed: () => _editBookDialog(item),
                                      ),
                                      // Delete button
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                        tooltip: 'حذف المذكرة من المخزن 🗑️',
                                        onPressed: () => _deleteBookDialog(item),
                                      ),
                                      // Barcode button
                                      IconButton(
                                        icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                                        tooltip: 'طباعة استيكر باركود للملزمة 🏷️',
                                        color: AppColors.primary,
                                        onPressed: () => _printBarcodeLabelsDialog(item),
                                      ),
                                      const SizedBox(width: 4),
                                      if (inCartQty > 0)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                              onPressed: () => _removeFromCart(item['id']),
                                            ),
                                            Text('$inCartQty', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            IconButton(
                                              icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 20),
                                              onPressed: () => _addToCart(item['id']),
                                            ),
                                          ],
                                        )
                                      else
                                        ElevatedButton.icon(
                                          onPressed: stock <= 0 ? null : () => _addToCart(item['id']),
                                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                                          label: const Text('إضافة'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            textStyle: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPane(bool isDark, Color textPrimary, Color textSecondary) {
    final total = _totalPrice;
    final totalItems = _cart.values.fold<int>(0, (s, e) => s + e);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(right: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('فاتورة البيع الحالية', style: AppTypography.titleMedium(textPrimary)),
                ],
              ),
              if (_cart.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _cart.clear()),
                  child: const Text('تفريغ السلة', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
            ],
          ),
          const Divider(),

          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_shopping_cart_outlined, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('السلة فارغة حالياً', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('اختر المذكرات من القائمة لإضافتها للفاتورة', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView(
                    children: _cart.entries.map((entry) {
                      final item = _inventory.firstWhere((b) => b['id'] == entry.key);
                      final qty = entry.value;
                      final subtotal = (item['price'] as double) * qty;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['title'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('${item['price']} ج.م × $qty', style: TextStyle(fontSize: 11, color: textSecondary)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${subtotal.toStringAsFixed(1)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              onPressed: () => setState(() => _cart.remove(entry.key)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('عدد النسخ: $totalItems', style: TextStyle(color: textSecondary, fontSize: 12)),
              Text(
                'الإجمالي: ${total.toStringAsFixed(1)} ج.م',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: _cart.isEmpty || _isProcessingSale ? null : _completeCashSale,
            icon: _isProcessingSale
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.point_of_sale_rounded),
            label: Text(_isProcessingSale ? 'جاري التحصيل...' : 'تحصيل نقدي وطباعة الإيصال'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
