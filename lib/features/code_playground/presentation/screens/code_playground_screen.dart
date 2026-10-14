import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../../core/localization/app_localizations.dart';
import '../../../../design_system/tokens/colors.dart';

class CodePlaygroundScreen extends StatefulWidget {
  const CodePlaygroundScreen({super.key});

  @override
  State<CodePlaygroundScreen> createState() => _CodePlaygroundScreenState();
}

class _CodePlaygroundScreenState extends State<CodePlaygroundScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _selectedLanguage = 'Dart';
  final List<String> _languages = ['Dart', 'Python', 'JS', 'C++'];
  bool _isRunning = false;
  bool _isTerminalExpanded = false;
  String _terminalOutput = '';
  String _runStage = '';
  _SortVisualization? _sortVisualization;
  double _fontSize = 14;
  int _currentLine = 1;
  int _currentCol = 1;

  final Map<String, List<({String title, String description, String code})>> _templates = {
    'Dart': [
      (
        title: 'برنامج ترحيبي (Hello World)',
        description: 'طباعة نص ترحيبي بسيط في كونسول دارت',
        code: 'void main() {\n  print("مرحباً بك في منصة بريفيو! 🚀");\n}\n',
      ),
      (
        title: 'متتالية فيبوناتشي (Fibonacci)',
        description: 'حساب وعرض أول 10 أرقام في المتتالية',
        code: 'void main() {\n  int n = 10;\n  int a = 0, b = 1;\n  print("Fibonacci series up to \$n terms:");\n  for (int i = 0; i < n; i++) {\n    print(a);\n    int next = a + b;\n    a = b;\n    b = next;\n  }\n}\n',
      ),
      (
        title: 'العمليات على القوائم (List Operations)',
        description: 'تصفية وحساب مجموع الأعداد الزوجية',
        code: 'void main() {\n  List<int> numbers = [12, 45, 7, 23, 56, 89, 34];\n  var evens = numbers.where((n) => n.isEven).toList();\n  print("All numbers: \$numbers");\n  print("Even numbers: \$evens");\n  print("Sum of all: \${numbers.reduce((a, b) => a + b)}");\n}\n',
      ),
    ],
    'Python': [
      (
        title: 'برنامج ترحيبي (Hello Python)',
        description: 'طباعة نص ترحيبي وتجربة المتغيرات',
        code: 'name = "Brivio Developer"\nprint(f"مرحباً بك يا {name} في بيئة بايثون! 🐍")\n',
      ),
      (
        title: 'فرز القوائم (Bubble Sort)',
        description: 'خوارزمية الفرز الفقاعي مع محاكاة مرئية',
        code: '# Bubble sort algorithm\nnumbers = [64, 34, 25, 12, 22, 11, 90]\nprint(f"Original: {numbers}")\n\nfor i in range(len(numbers)):\n    for j in range(0, len(numbers) - i - 1):\n        if numbers[j] > numbers[j + 1]:\n            numbers[j], numbers[j + 1] = numbers[j + 1], numbers[j]\n\nprint(f"Sorted: {numbers}")\n',
      ),
      (
        title: 'الأعداد الأولية (Prime Numbers)',
        description: 'إيجاد جميع الأعداد الأولية الأقل من 50',
        code: 'def is_prime(n):\n    if n <= 1:\n        return False\n    for i in range(2, int(n**0.5) + 1):\n        if n % i == 0:\n            return False\n    return True\n\nprimes = [x for x in range(2, 50) if is_prime(x)]\nprint(f"الأعداد الأولية حتى 50: {primes}")\n',
      ),
    ],
    'JS': [
      (
        title: 'برنامج ترحيبي (Hello JS)',
        description: 'طباعة رسالة في الكونسول',
        code: 'console.log("مرحباً بك في JavaScript! ⚡");\n',
      ),
      (
        title: 'معالجة مصفوفة طلاب (Students Array)',
        description: 'تصفية الطلاب المتفوقين باستخدام filter و map',
        code: 'const students = [\n  { name: "Ahmed", score: 92 },\n  { name: "Sara", score: 85 },\n  { name: "Omar", score: 98 },\n  { name: "Mona", score: 76 }\n];\n\nconst topStudents = students\n  .filter(s => s.score >= 90)\n  .map(s => `\${s.name} (\${s.score}%)`);\n\nconsole.log("Top Students:", topStudents.join(", "));\n',
      ),
    ],
    'C++': [
      (
        title: 'برنامج ترحيبي (Hello C++)',
        description: 'برنامج أساسي يستخدم iostream',
        code: '#include <iostream>\nusing namespace std;\n\nint main() {\n    cout << "مرحباً بك في عالم C++ الاحترافي!" << endl;\n    return 0;\n}\n',
      ),
      (
        title: 'ترتيب متجهات (Vector Sorting)',
        description: 'استخدام vector و std::sort',
        code: '#include <iostream>\n#include <vector>\n#include <algorithm>\nusing namespace std;\n\nint main() {\n    vector<int> v = {42, 12, 88, 3, 55};\n    cout << "Before: ";\n    for (int x : v) cout << x << " ";\n    cout << endl;\n\n    sort(v.begin(), v.end());\n\n    cout << "After:  ";\n    for (int x : v) cout << x << " ";\n    cout << endl;\n    return 0;\n}\n',
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_updateCursorPosition);
    _codeController.text = _templates[_selectedLanguage]?.first.code ?? '';
  }

  void _updateCursorPosition() {
    final text = _codeController.text;
    final selection = _codeController.selection;
    if (selection.baseOffset < 0) return;
    final offset = selection.baseOffset.clamp(0, text.length);
    final lines = text.substring(0, offset).split('\n');
    final line = lines.length;
    final col = lines.isEmpty ? 1 : lines.last.length + 1;
    if (_currentLine != line || _currentCol != col) {
      setState(() {
        _currentLine = line;
        _currentCol = col;
      });
    }
  }

  void _insertSymbol(String symbol) {
    final selection = _codeController.selection;
    final text = _codeController.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    String insertText = symbol;
    int cursorOffset = insertText.length;

    if (symbol == 'Tab') {
      insertText = '  ';
      cursorOffset = 2;
    } else if (symbol == '()') {
      insertText = '()';
      cursorOffset = 1;
    } else if (symbol == '{}') {
      insertText = '{\n  \n}';
      cursorOffset = 4;
    } else if (symbol == '[]') {
      insertText = '[]';
      cursorOffset = 1;
    } else if (symbol == '""') {
      insertText = '""';
      cursorOffset = 1;
    } else if (symbol == "''") {
      insertText = "''";
      cursorOffset = 1;
    }

    final newText = text.replaceRange(start, end, insertText);
    _codeController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + cursorOffset),
    );
    _codeFocus.requestFocus();
  }

  void _runCode() async {
    final code = _codeController.text;
    if (code.trim().isEmpty) {
      setState(() {
        _isTerminalExpanded = true;
        _terminalOutput = 'Error: Code is empty.';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _isTerminalExpanded = true;
      _runStage = 'Preparing sandbox';
      _terminalOutput = 'Preparing sandbox...';
      _sortVisualization = _SortVisualization.fromCode(code);
    });

    String compilerId;
    switch (_selectedLanguage) {
      case 'Dart':
        compilerId = 'dart373';
        break;
      case 'Python':
        compilerId = 'python311';
        break;
      case 'JS':
        compilerId = 'v8113';
        break;
      case 'C++':
        compilerId = 'g132';
        break;
      default:
        compilerId = 'python311';
    }

    try {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (mounted) {
        setState(() => _runStage = 'Compiling');
      }
      final response = await http
          .post(
            Uri.parse('https://godbolt.org/api/compiler/$compilerId/compile'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              "source": code,
              "compiler": compilerId,
              "options": {
                "userArguments": "",
                "executeParameters": {"args": [], "stdin": ""},
                "compilerOptions": {"executorRequest": true},
                "filters": {"execute": true},
                "tools": [],
                "libraries": [],
              },
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (mounted) {
        setState(() {
          _isRunning = false;
          _runStage = 'Finished';
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            String output = '';

            if (data['stdout'] != null) {
              for (var line in data['stdout']) {
                output += (line['text'] ?? '') + '\n';
              }
            }
            if (data['stderr'] != null) {
              for (var line in data['stderr']) {
                output += (line['text'] ?? '') + '\n';
              }
            }
            if (data['buildResult'] != null &&
                data['buildResult']['stderr'] != null) {
              for (var line in data['buildResult']['stderr']) {
                final text = line['text'] ?? '';
                if (text.isNotEmpty &&
                    !text.startsWith('<Compilation failed>')) {
                  output += text + '\n';
                }
              }
            }

            _terminalOutput = output.trim().isEmpty
                ? 'Program finished with no output.'
                : output.trim();
          } else {
            _terminalOutput =
                'Execution failed. Server responded with status code ${response.statusCode}.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _runStage = 'Stopped';
          _terminalOutput = e is TimeoutException
              ? 'Execution timed out after 20 seconds. Try smaller input or run again.'
              : 'Error connecting to execution API:\n$e';
        });
      }
    }
  }

  void _showTemplatesSheet() {
    final list = _templates[_selectedLanguage] ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'نماذج برمجية جاهزة ($_selectedLanguage)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = list[i];
                    return ListTile(
                      tileColor: const Color(0xFF282A36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: const Icon(Icons.code_rounded, color: AppColors.primary),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        item.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_left_rounded, color: Colors.white54),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _codeController.text = item.code;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _formatCode() {
    var indent = 0;
    final formatted = <String>[];
    for (final raw in _codeController.text.split('\n')) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        formatted.add('');
        continue;
      }
      if (trimmed.startsWith('}') || trimmed.startsWith(')')) {
        indent = (indent - 1).clamp(0, 99);
      }
      formatted.add('${'  ' * indent}$trimmed');
      if (trimmed.endsWith('{') || trimmed.endsWith(':')) indent++;
    }
    final next = formatted.join('\n');
    _codeController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  void dispose() {
    _codeController.removeListener(_updateCursorPosition);
    _codeController.dispose();
    _codeFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getFileExtension(String lang) {
    switch (lang) {
      case 'Dart':
        return 'main.dart';
      case 'Python':
        return 'main.py';
      case 'JS':
        return 'index.js';
      case 'C++':
        return 'main.cpp';
      default:
        return 'script.txt';
    }
  }

  IconData _getFileIcon(String lang) {
    switch (lang) {
      case 'Dart':
        return Icons.flutter_dash_rounded;
      case 'Python':
        return Icons.terminal_rounded;
      case 'JS':
        return Icons.javascript_rounded;
      case 'C++':
        return Icons.data_object_rounded;
      default:
        return Icons.code_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141721),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B202E),
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF262D40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38435E), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLanguage,
              dropdownColor: const Color(0xFF1B202E),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
              ),
              onChanged: (String? newValue) {
                if (newValue != null && newValue != _selectedLanguage) {
                  setState(() {
                    _selectedLanguage = newValue;
                    _codeController.text = _templates[newValue]?.first.code ?? '';
                  });
                }
              },
              items: _languages.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getFileIcon(value), size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(value),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isRunning ? null : _runCode,
                icon: _isRunning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  _isRunning ? 'جاري التشغيل...' : 'تشغيل (Run)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: _ProfessionalCodeEditor(
                    controller: _codeController,
                    focusNode: _codeFocus,
                    scrollController: _scrollController,
                    language: _selectedLanguage,
                    fileName: _getFileExtension(_selectedLanguage),
                    fontSize: _fontSize,
                    onOpenTemplates: _showTemplatesSheet,
                    onFormat: _formatCode,
                    onClear: () => _codeController.clear(),
                    onFontSizeChanged: (value) => setState(() => _fontSize = value),
                    onInsertSymbol: _insertSymbol,
                    currentLine: _currentLine,
                    currentCol: _currentCol,
                  ),
                ),
              ],
            ),
          ),
          if (_isTerminalExpanded)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy > 10) {
                    setState(() {
                      _isTerminalExpanded = false;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F131D),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 16,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  height: _sortVisualization == null ? 330 : 440,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.terminal_rounded, color: AppColors.success, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Terminal Output',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (_runStage.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                _RunStagePill(
                                  label: _runStage,
                                  isRunning: _isRunning,
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'نسخ المخرجات',
                                icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _terminalOutput));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ مخرجات الكونسول إلى الحافظة 📋'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'مسح المخرجات',
                                icon: const Icon(Icons.cleaning_services_rounded, color: Colors.white70, size: 18),
                                onPressed: () => setState(() => _terminalOutput = ''),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                onPressed: () => setState(() => _isTerminalExpanded = false),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_sortVisualization != null) ...[
                        SizedBox(
                          height: 122,
                          child: _SortVisualizer(
                            visualization: _sortVisualization!,
                            isRunning: _isRunning,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090B10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _terminalOutput,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF4ADE80),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RunStagePill extends StatelessWidget {
  final String label;
  final bool isRunning;

  const _RunStagePill({required this.label, required this.isRunning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isRunning ? AppColors.warning : AppColors.success).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (isRunning ? AppColors.warning : AppColors.success).withValues(
            alpha: 0.28,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRunning)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (isRunning) const SizedBox(width: 6),
          Text(
            context.tr(label),
            style: TextStyle(
              color: isRunning ? AppColors.warning : AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SortVisualizer extends StatefulWidget {
  final _SortVisualization visualization;
  final bool isRunning;

  const _SortVisualizer({required this.visualization, required this.isRunning});

  @override
  State<_SortVisualizer> createState() => _SortVisualizerState();
}

class _SortVisualizerState extends State<_SortVisualizer> {
  Timer? _timer;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _SortVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visualization != widget.visualization ||
        oldWidget.isRunning != widget.isRunning) {
      _timer?.cancel();
      _stepIndex = 0;
      _start();
    }
  }

  void _start() {
    if (!widget.isRunning || widget.visualization.steps.length <= 1) return;
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() {
        _stepIndex = (_stepIndex + 1) % widget.visualization.steps.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget
        .visualization
        .steps[_stepIndex.clamp(0, widget.visualization.steps.length - 1)];
    final maxValue = step.values.fold<int>(1, (max, v) => v > max ? v : max);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF243044)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_graph,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < step.values.length; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        height: 24 + (step.values[i] / maxValue) * 54,
                        decoration: BoxDecoration(
                          color: step.highlighted.contains(i)
                              ? AppColors.warning
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          '${step.values[i]}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (i < step.values.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortVisualization {
  final List<_SortStep> steps;

  const _SortVisualization(this.steps);

  static _SortVisualization? fromCode(String code) {
    if (!code.toLowerCase().contains('sort')) return null;
    final match = RegExp(r'\[([0-9,\s-]+)\]').firstMatch(code);
    if (match == null) return null;
    final values = match
        .group(1)!
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((value) => value >= 0)
        .take(10)
        .toList();
    if (values.length < 2) return null;

    final steps = <_SortStep>[
      _SortStep(List<int>.from(values), const {}, 'Visualizer: initial list'),
    ];
    final working = List<int>.from(values);
    for (var i = 0; i < working.length; i++) {
      for (var j = 0; j < working.length - i - 1; j++) {
        steps.add(
          _SortStep(List<int>.from(working), {
            j,
            j + 1,
          }, 'Compare ${working[j]} and ${working[j + 1]}'),
        );
        if (working[j] > working[j + 1]) {
          final temp = working[j];
          working[j] = working[j + 1];
          working[j + 1] = temp;
          steps.add(
            _SortStep(List<int>.from(working), {
              j,
              j + 1,
            }, 'Swap into ascending order'),
          );
        }
      }
    }
    steps.add(_SortStep(List<int>.from(working), const {}, 'Sorted result'));
    return _SortVisualization(steps);
  }
}

class _SortStep {
  final List<int> values;
  final Set<int> highlighted;
  final String message;

  const _SortStep(this.values, this.highlighted, this.message);
}

class _ProfessionalCodeEditor extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final String language;
  final String fileName;
  final double fontSize;
  final VoidCallback onOpenTemplates;
  final VoidCallback onFormat;
  final VoidCallback onClear;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<String> onInsertSymbol;
  final int currentLine;
  final int currentCol;

  const _ProfessionalCodeEditor({
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.language,
    required this.fileName,
    required this.fontSize,
    required this.onOpenTemplates,
    required this.onFormat,
    required this.onClear,
    required this.onFontSizeChanged,
    required this.onInsertSymbol,
    required this.currentLine,
    required this.currentCol,
  });

  static const List<String> _quickSymbols = [
    'Tab',
    '{}',
    '()',
    '[]',
    ';',
    ':',
    '=',
    '""',
    "''",
    '+',
    '-',
    '*',
    '/',
    '.',
    ',',
    '!',
    '&&',
    '||',
    '//',
    '<',
    '>',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E3447), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Tab & Action Header
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF181824),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFF2E3447))),
            ),
            child: Row(
              children: [
                // Active file tab
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    border: Border(top: BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.code_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'قوالب جاهزة (Templates)',
                  icon: const Icon(Icons.auto_awesome_rounded, color: Colors.purpleAccent, size: 18),
                  onPressed: onOpenTemplates,
                ),
                IconButton(
                  tooltip: 'تنسيق الكود (Format)',
                  icon: const Icon(Icons.auto_fix_high_rounded, color: Colors.amberAccent, size: 18),
                  onPressed: onFormat,
                ),
                IconButton(
                  tooltip: 'مسح الكود (Clear)',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  onPressed: onClear,
                ),
                PopupMenuButton<double>(
                  tooltip: 'حجم الخط',
                  icon: const Icon(Icons.format_size_rounded, color: Colors.white70, size: 18),
                  onSelected: onFontSizeChanged,
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 12, child: Text('خط صغير (12pt)')),
                    const PopupMenuItem(value: 14, child: Text('خط عادي (14pt)')),
                    const PopupMenuItem(value: 16, child: Text('خط متوسط (16pt)')),
                    const PopupMenuItem(value: 18, child: Text('خط كبير (18pt)')),
                  ],
                ),
              ],
            ),
          ),

          // Code Canvas with Line Numbers
          Expanded(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final lineCount = controller.text.split('\n').length.clamp(1, 99999);
                return SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gutter (Line Numbers)
                      Container(
                        width: 48,
                        padding: const EdgeInsets.only(top: 14, right: 8, bottom: 20),
                        decoration: const BoxDecoration(
                          color: Color(0xFF161622),
                          border: Border(right: BorderSide(color: Color(0xFF2E3447))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 1; i <= lineCount; i++)
                              SizedBox(
                                height: fontSize * 1.5,
                                child: Text(
                                  '$i',
                                  style: TextStyle(
                                    color: i == currentLine
                                        ? AppColors.primary
                                        : const Color(0xFF5A627A),
                                    fontWeight: i == currentLine
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontFamily: 'monospace',
                                    fontSize: fontSize - 1,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Code TextField
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLines: null,
                          scrollPhysics: const NeverScrollableScrollPhysics(),
                          textAlignVertical: TextAlignVertical.top,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: const Color(0xFFF8F8F2),
                            fontSize: fontSize,
                            height: 1.5,
                          ),
                          cursorColor: AppColors.primary,
                          cursorWidth: 2,
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            contentPadding: EdgeInsets.fromLTRB(12, 14, 12, 20),
                            border: InputBorder.none,
                            hintText: '// اكتب الكود هنا أو اختر قالباً جاهزاً...',
                            hintStyle: TextStyle(
                              color: Color(0xFF6272A4),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Mobile Quick Symbols Accessory Row
          Container(
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF161622),
              border: Border(
                top: BorderSide(color: Color(0xFF2E3447)),
                bottom: BorderSide(color: Color(0xFF2E3447)),
              ),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _quickSymbols.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final sym = _quickSymbols[i];
                return InkWell(
                  onTap: () => onInsertSymbol(sym),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25293A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF384058)),
                    ),
                    child: Text(
                      sym,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // VS Code-style Status Bar
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF10121A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Ln $currentLine, Col $currentCol',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(width: 12),
                const Text('UTF-8', style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(width: 12),
                const Text('Spaces: 2', style: TextStyle(color: Colors.white54, fontSize: 11)),
                const Spacer(),
                Text(
                  language,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
