import 'package:flutter/material.dart';
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

  // Real students loaded from Supabase
  List<Map<String, dynamic>> _students = [];
  Map<String, dynamic>? _selectedStudent;
  bool _isLoadingStudents = false;

  final List<Map<String, dynamic>> _inventory = [];
  bool _isLoadingInventory = false;

  final Map<String, int> _cart = {}; // bookId -> quantity
  bool _isProcessingSale = false;

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
    _loadCenterInfo();
    _loadStudents();
    _loadInventory();
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
          if (centerId != null && widget.centerName == null) {
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
    } catch (_) {}
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
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

  Future<void> _loadInventory() async {
    setState(() => _isLoadingInventory = true);
    try {
      final subjectsRes = await Supabase.instance.client
          .from('subjects')
          .select('id, name')
          .eq('status', 'active');

      final List<Map<String, dynamic>> items = [];
      for (final s in (subjectsRes as List<dynamic>)) {
        items.add({
          'id': 'sub-${s['id']}',
          'title': 'ملزمة مادة ${s['name']}',
          'teacher': 'القسم الأكاديمي',
          'price': 40.0,
          'stock': 50,
        });
      }

      if (mounted) {
        setState(() {
          _inventory.clear();
          _inventory.addAll(items);
          _isLoadingInventory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _inventory.clear();
          _isLoadingInventory = false;
        });
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
        title: const Text('إضافة مذكرة / ملزمة جديدة للمخزن'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'اسم المذكرة أو الملزمة'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: teacherCtrl,
                decoration: const InputDecoration(labelText: 'اسم الأستاذ / المادة'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سعر البيع (ج.م)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية المتوفرة بالمخزن'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              final teacher = teacherCtrl.text.trim().isEmpty ? 'السنتر' : teacherCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 40.0;
              final stock = int.tryParse(stockCtrl.text.trim()) ?? 30;
              if (title.isNotEmpty) {
                setState(() {
                  _inventory.add({
                    'id': 'custom-${DateTime.now().millisecondsSinceEpoch}',
                    'title': title,
                    'teacher': teacher,
                    'price': price,
                    'stock': stock,
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة'),
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
    _cart.forEach((bookId, qty) {
      final item = _inventory.firstWhere((b) => b['id'] == bookId);
      item['stock'] = (item['stock'] as int) - qty;
      receiptItems.add({
        'title': item['title'],
        'price': item['price'],
        'quantity': qty,
      });
    });

    final receiptNumber = 'BK-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final total = _totalPrice;

    final studentName = _selectedStudent != null
        ? _selectedStudent!['name']?.toString() ?? 'طالب نقدي'
        : 'طالب نقدي عام';
    final studentCode = _selectedStudent != null
        ? _selectedStudent!['code']?.toString() ?? 'GEN-CASH'
        : 'GEN-CASH';

    final isDirectPrint = ThermalPrinterService().directPrintEnabled.value;

    try {
      final reportService = ReportGeneratorService();
      await reportService.generateBookstoreReceiptPdf(
        centerName: _centerName,
        receiptNumber: receiptNumber,
        studentName: studentName,
        studentCode: studentCode,
        cashierName: _cashierName,
        saleDate: DateTime.now(),
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
        content: Text('تم تحصيل $total ج.م نقداً وخصم المذكرات وطباعة الإيصال #$receiptNumber ✔️'),
      ),
    );
  }

  Future<void> _printBarcodeLabelsDialog([Map<String, dynamic>? singleItem]) async {
    final countCtrl = TextEditingController(text: '12');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
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
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                tooltip: 'إضافة مذكرة للمخزن',
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
                              'اضغط على زر (+) بالأعلى لإضافة ملزمة جديدة للبيع',
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
                                                color: isLowStock ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isLowStock ? 'متبقي بالمخزن: $stock فقط ⚠️' : 'متوفر بالمخزن: $stock نسخة',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isLowStock ? Colors.red.shade800 : Colors.green.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
