import 'package:flutter/material.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../core/services/thermal_printer_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../widgets/thermal_printer_settings_dialog.dart';

class BookstorePosScreen extends StatefulWidget {
  final String centerName;
  final String cashierName;

  const BookstorePosScreen({
    super.key,
    this.centerName = 'سنتر الأوائل التعليمي',
    this.cashierName = 'أمين الخزينة والمخزن',
  });

  @override
  State<BookstorePosScreen> createState() => _BookstorePosScreenState();
}

class _BookstorePosScreenState extends State<BookstorePosScreen> {
  final _studentSearchController = TextEditingController(text: 'عمر أحمد محمود (STU-101)');
  final _searchBookController = TextEditingController();

  final List<Map<String, dynamic>> _inventory = [
    {
      'id': 'bk-1',
      'title': 'مذكرة فيزياء 3 ث (قوانين كيرشوف والدوائر)',
      'teacher': 'أ. محمد عبد الله',
      'price': 65.0,
      'stock': 42,
    },
    {
      'id': 'bk-2',
      'title': 'كتاب بنك الأسئلة والتدريبات الشاملة (رياضيات)',
      'teacher': 'أ. أحمد الشناوي',
      'price': 90.0,
      'stock': 18,
    },
    {
      'id': 'bk-3',
      'title': 'ملزمة الكيمياء العضوية ونماذج الامتحانات',
      'teacher': 'أ. محمود رضوان',
      'price': 55.0,
      'stock': 6, // Low stock!
    },
    {
      'id': 'bk-4',
      'title': 'مذكرة القواعد النحوية الشاملة والتدريبات',
      'teacher': 'أ. طارق عبد العزيز',
      'price': 45.0,
      'stock': 75,
    },
    {
      'id': 'bk-5',
      'title': 'كراسة المتابعة والواجبات الأسبوعية للسنتر',
      'teacher': 'إدارة السنتر',
      'price': 25.0,
      'stock': 120,
    },
  ];

  final Map<String, int> _cart = {}; // bookId -> quantity
  bool _isProcessingSale = false;

  @override
  void initState() {
    super.initState();
    ThermalPrinterService().init();
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _searchBookController.dispose();
    super.dispose();
  }

  double get _totalPrice {
    double total = 0.0;
    _cart.forEach((bookId, qty) {
      final item = _inventory.firstWhere((b) => b['id'] == bookId);
      total += (item['price'] as double) * qty;
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

    // Prepare item list
    final receiptItems = <Map<String, dynamic>>[];
    _cart.forEach((bookId, qty) {
      final item = _inventory.firstWhere((b) => b['id'] == bookId);
      // Deduct stock
      item['stock'] = (item['stock'] as int) - qty;
      receiptItems.add({
        'title': item['title'],
        'price': item['price'],
        'quantity': qty,
      });
    });

    final receiptNumber = 'BK-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final total = _totalPrice;

    final isDirectPrint = ThermalPrinterService().directPrintEnabled.value;

    // Generate electronic PDF receipt (or silent thermal print if enabled)
    try {
      final reportService = ReportGeneratorService();
      await reportService.generateBookstoreReceiptPdf(
        centerName: widget.centerName,
        receiptNumber: receiptNumber,
        studentName: _studentSearchController.text.trim().split('(').first.trim(),
        studentCode: 'STU-101',
        cashierName: widget.cashierName,
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
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: Text('تم تحصيل $total ج.م نقداً وخصم المذكرات من المخزن وطباعة الإيصال #$receiptNumber ✔️'),
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('نظام بيع المذكرات والمخزن (POS) 📦'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'إعدادات الطابعة الحرارية (ESC/POS)',
            onPressed: () => ThermalPrinterSettingsDialog.show(context, centerName: widget.centerName),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Pane: Inventory Catalog
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Student selector
                  TextField(
                    controller: _studentSearchController,
                    decoration: const InputDecoration(
                      labelText: 'الطالب المشتري',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Search booklet
                  TextField(
                    controller: _searchBookController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'ابحث باسم المذكرة أو الأستاذ...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Items grid/list
                  Expanded(
                    child: ListView.builder(
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
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'المدرس: ${item['teacher']} • السعر: ${item['price']} ج.م',
                                        style: TextStyle(fontSize: 11, color: textSecondary),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
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
                                          if (inCartQty > 0) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '$inCartQty في السلة',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                                  onPressed: stock > 0 ? () => _addToCart(item['id']) : null,
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
            ),
          ),

          // Right Pane: POS Cart & Checkout
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border(
                  right: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'فاتورة البيع الحالية 🛒',
                          style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_cart.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _cart.clear()),
                          child: const Text('تفريغ', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Cart items list
                  Expanded(
                    child: _cart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shopping_basket_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                Text('السلة فارغة، أضف مذكرات للبيع', style: TextStyle(color: textSecondary, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView(
                            children: _cart.entries.map((e) {
                              final book = _inventory.firstWhere((b) => b['id'] == e.key);
                              final qty = e.value;
                              final subtotal = (book['price'] as double) * qty;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              book['title'],
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${book['price']} × $qty = ${subtotal.toStringAsFixed(1)} ج.م',
                                              style: TextStyle(fontSize: 11, color: textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                                            onPressed: () => _removeFromCart(e.key),
                                          ),
                                          Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                            onPressed: () => _addToCart(e.key),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  const Divider(height: 20),

                  // Cash Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'المطلوب كاش:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_totalPrice.toStringAsFixed(1)} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isProcessingSale ? null : _completeCashSale,
                    icon: _isProcessingSale
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.payments_rounded),
                    label: Text(
                      _isProcessingSale ? 'جارٍ إصدار الإيصال...' : 'تحصيل كاش وطباعة الإيصال 💵',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
