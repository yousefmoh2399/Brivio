import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';

class StudyReplayScreen extends StatefulWidget {
  final String? teacherId;

  const StudyReplayScreen({super.key, this.teacherId});

  @override
  State<StudyReplayScreen> createState() => _StudyReplayScreenState();
}

class _StudyReplayScreenState extends State<StudyReplayScreen>
    with SingleTickerProviderStateMixin {
  Timer? _playbackTimer;
  bool _isLoading = false;
  bool _isPlaying = false;
  String? _errorMessage;
  List<_ReplaySession> _sessions = [];
  List<_ReplayEvent> _events = [];
  _ReplaySession? _selectedSession;
  int _playbackMs = 0;

  final TextEditingController _sessionSearchController = TextEditingController();
  TabController? _mobileTabController;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 2, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _sessionSearchController.dispose();
    _mobileTabController?.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = widget.teacherId == null
          ? await Supabase.instance.client
                .from('study_sessions')
                .select(
                  'id, student_id, lesson_id, started_at, ended_at, duration_seconds, pages_read, students(student_code, profiles(full_name)), lessons(title)',
                )
                .order('started_at', ascending: false)
                .limit(80)
          : await Supabase.instance.client.rpc(
              'get_teacher_study_replay_sessions',
              params: {'p_teacher_id': widget.teacherId},
            );

      final sessions = (rows as List)
          .whereType<Map>()
          .map(_ReplaySession.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _selectedSession = sessions.isEmpty ? null : sessions.first;
        _isLoading = false;
      });
      if (_selectedSession != null) {
        await _loadEvents(_selectedSession!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEvents(_ReplaySession session, {bool switchToPlayerOnMobile = false}) async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_study_replay_events',
        params: {'p_session_id': session.id},
      );
      if (!mounted) return;
      setState(() {
        _selectedSession = session;
        _events = (rows as List)
            .whereType<Map>()
            .map(_ReplayEvent.fromJson)
            .toList();
        _playbackMs = 0;
        _isPlaying = false;
      });
      _playbackTimer?.cancel();

      if (switchToPlayerOnMobile && _mobileTabController != null) {
        _mobileTabController!.animateTo(1);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  void _togglePlayback() {
    if (_events.isEmpty) return;
    if (_isPlaying) {
      _playbackTimer?.cancel();
      setState(() => _isPlaying = false);
      return;
    }
    setState(() => _isPlaying = true);
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      final maxMs = _events.isEmpty ? 0 : _events.last.offsetMs;
      setState(() {
        _playbackMs = (_playbackMs + 1000).clamp(0, maxMs);
        if (_playbackMs >= maxMs) {
          _isPlaying = false;
          _playbackTimer?.cancel();
        }
      });
    });
  }

  void _seekPlayback(double value) {
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _playbackMs = value.round();
    });
  }

  List<_ReplaySession> get _filteredSessions {
    final query = _sessionSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _sessions;
    return _sessions.where((s) {
      final name = s.studentName.toLowerCase();
      final lesson = s.lessonTitle.toLowerCase();
      return name.contains(query) || lesson.contains(query);
    }).toList();
  }

  Widget _buildKpiSection() {
    final totalSessions = _sessions.length;
    final totalSeconds = _sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final totalHours = (totalSeconds / 3600).toStringAsFixed(1);
    final totalPages = _sessions.fold<int>(0, (sum, s) => sum + s.pagesRead);
    final eventsCount = _events.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        final items = [
          _buildKpiCard(
            title: 'إجمالي الجلسات المسجلة',
            value: totalSessions.toString(),
            icon: Icons.video_library_rounded,
            color: AppColors.adminRole,
            subtitle: 'جلسات دراسية موثقة',
          ),
          _buildKpiCard(
            title: 'إجمالي ساعات المذاكرة',
            value: '$totalHours ساعة',
            icon: Icons.timelapse_rounded,
            color: Colors.teal,
            subtitle: '${(totalSeconds ~/ 60)} دقيقة تفاعل دراسي',
          ),
          _buildKpiCard(
            title: 'الصفحات المقروءة',
            value: '$totalPages صفحة',
            icon: Icons.menu_book_rounded,
            color: Colors.indigo,
            subtitle: 'تصفح وقراءة مذكرات',
          ),
          _buildKpiCard(
            title: 'أحداث الجلسة النشطة',
            value: eventsCount.toString(),
            icon: Icons.timeline_rounded,
            color: Colors.deepOrange,
            subtitle: _selectedSession != null
                ? _selectedSession!.lessonTitle
                : 'حدد جلسة للعرض',
          ),
        ];

        if (isDesktop) {
          return Row(
            children: items
                .map((widget) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: widget,
                      ),
                    ))
                .toList(),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: items[0]),
                const SizedBox(width: 8),
                Expanded(child: items[1]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: items[2]),
                const SizedBox(width: 8),
                Expanded(child: items[3]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.teacherId == null
        ? AppColors.adminRole
        : AppColors.teacherRole;

    return PortalPageShell(
      title: 'تسجيلات الحصص ومسارات المذاكرة',
      subtitle:
          'إعادة تشغيل تفاعلية لجلسات دراسة الطلاب، تتبع تصفح الدروس، وتدوين الملاحظات لحظياً.',
      icon: Icons.video_library_rounded,
      accentColor: accentColor,
      actions: [
        PortalAction(
          icon: Icons.refresh_rounded,
          label: 'تحديث الجلسات',
          onPressed: _loadSessions,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpiSection(),
          const SizedBox(height: 14),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: _sessions.isEmpty,
              emptyTitle: 'لا توجد جلسات دراسية مسجلة',
              emptySubtitle:
                  'تظهر بيانات الجلسات بمجرد تفاعل الطلاب مع الدروس والمذكرات الدراسية.',
              emptyIcon: Icons.video_library_rounded,
              onRetry: _loadSessions,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Panel: Sessions List (Width 360)
                        SizedBox(
                          width: 360,
                          child: Column(
                            children: [
                              _buildSearchField(),
                              const SizedBox(height: 10),
                              Expanded(
                                child: _buildSessionListView(
                                  isMobile: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Right Panel: Interactive Replay & Events Timeline
                        Expanded(
                          child: _buildTimelinePanel(),
                        ),
                      ],
                    );
                  }

                  // Mobile Tabbed View (Clean and non-nested)
                  return Column(
                    children: [
                      TabBar(
                        controller: _mobileTabController,
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.list_alt_rounded),
                            text: 'قائمة الجلسات (${_filteredSessions.length})',
                          ),
                          Tab(
                            icon: const Icon(Icons.play_circle_filled_rounded),
                            text: 'مشغل المسار (${_events.length})',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: TabBarView(
                          controller: _mobileTabController,
                          children: [
                            Column(
                              children: [
                                _buildSearchField(),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: _buildSessionListView(
                                    isMobile: true,
                                  ),
                                ),
                              ],
                            ),
                            _buildTimelinePanel(),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _sessionSearchController,
      decoration: InputDecoration(
        hintText: 'بحث باسم الطالب أو عنوان الدرس...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIcon: _sessionSearchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  _sessionSearchController.clear();
                  setState(() {});
                },
              )
            : null,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSessionListView({required bool isMobile}) {
    final filtered = _filteredSessions;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'لا توجد جلسات مطابقة للبحث.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = filtered[index];
        final isSelected = _selectedSession?.id == session.id;

        return InkWell(
          onTap: () => _loadEvents(
            session,
            switchToPlayerOnMobile: isMobile,
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.adminRole.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.adminRole
                    : Theme.of(context).dividerColor.withValues(alpha: 0.12),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.adminRole
                        : AppColors.adminRole.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: isSelected ? Colors.white : AppColors.adminRole,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.lessonTitle,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${session.durationSeconds} ثانية',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${session.pagesRead} صفحات',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          Text(
                            session.startedLabel,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelinePanel() {
    final selected = _selectedSession;
    if (selected == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 54,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'اختر جلسة من القائمة لعرض مسارها وتشغيل أحداثها.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 54,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد أحداث مسجلة لجلسة "${selected.lessonTitle}".',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    final maxMs = _events.last.offsetMs <= 0 ? 1 : _events.last.offsetMs;
    final visibleEvents = _events
        .where((event) => event.offsetMs <= _playbackMs)
        .toList();
    final currentEvent = visibleEvents.isEmpty
        ? _events.first
        : visibleEvents.last;

    return Column(
      children: [
        // ── Player Console ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.adminRole.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session Meta Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.adminRole.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.video_library_rounded,
                      color: AppColors.adminRole,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.lessonTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'الطالب: ${selected.studentName} • ${selected.startedLabel}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isPlaying
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPlaying ? Icons.play_arrow : Icons.pause,
                          size: 14,
                          color: _isPlaying ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isPlaying ? 'قيد التشغيل' : 'متوقف',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isPlaying ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Scrubbing Controls
              Row(
                children: [
                  IconButton.filled(
                    tooltip: _isPlaying ? 'إيقاف مؤقت' : 'تشغيل التسجيل',
                    onPressed: _togglePlayback,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.adminRole,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _playbackMs.clamp(0, maxMs).toDouble(),
                      min: 0,
                      max: maxMs.toDouble(),
                      activeColor: AppColors.adminRole,
                      onChanged: _seekPlayback,
                    ),
                  ),
                  Text(
                    '${_formatMs(_playbackMs)} / ${_formatMs(maxMs)}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Active Event Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: currentEvent.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: currentEvent.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(currentEvent.icon, size: 16, color: currentEvent.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الحدث الحالي: ${currentEvent.eventType.replaceAll('_', ' ')} (${currentEvent.offsetLabel})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: currentEvent.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Events Timeline ──
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final event = _events[index];
              final reached = event.offsetMs <= _playbackMs;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: reached
                      ? event.color.withValues(alpha: 0.08)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: reached
                        ? event.color.withValues(alpha: 0.4)
                        : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                    width: reached ? 1.2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      reached ? event.icon : Icons.radio_button_unchecked,
                      color: reached ? event.color : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.eventType.replaceAll('_', ' '),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: reached ? event.color : null,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: event.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  event.offsetLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: event.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (event.payload.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatPayload(event.payload),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatMs(int ms) {
    final seconds = ms ~/ 1000;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  String _formatPayload(Map<String, dynamic> payload) {
    final parts = <String>[];
    payload.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) {
        parts.add('$k: $v');
      }
    });
    return parts.join(' • ');
  }
}

class _ReplaySession {
  final String id;
  final String studentName;
  final String lessonTitle;
  final int durationSeconds;
  final int pagesRead;
  final DateTime startedAt;

  const _ReplaySession({
    required this.id,
    required this.studentName,
    required this.lessonTitle,
    required this.durationSeconds,
    required this.pagesRead,
    required this.startedAt,
  });

  factory _ReplaySession.fromJson(Map row) {
    final student = _asMap(row['students']);
    final profile = _asMap(student['profiles']);
    final lesson = _asMap(row['lessons']);
    return _ReplaySession(
      id: row['id']?.toString() ?? '',
      studentName:
          profile['full_name']?.toString() ??
          student['student_code']?.toString() ??
          row['student_full_name']?.toString() ??
          'Student',
      lessonTitle:
          lesson['title']?.toString() ??
          row['lesson_title']?.toString() ??
          'Lesson',
      durationSeconds:
          int.tryParse(row['duration_seconds']?.toString() ?? '') ?? 0,
      pagesRead: int.tryParse(row['pages_read']?.toString() ?? '') ?? 0,
      startedAt:
          DateTime.tryParse(row['started_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get startedLabel {
    final month = startedAt.month.toString().padLeft(2, '0');
    final day = startedAt.day.toString().padLeft(2, '0');
    return '${startedAt.year}-$month-$day';
  }
}

class _ReplayEvent {
  final String eventType;
  final int offsetMs;
  final Map<String, dynamic> payload;

  const _ReplayEvent({
    required this.eventType,
    required this.offsetMs,
    required this.payload,
  });

  factory _ReplayEvent.fromJson(Map row) {
    return _ReplayEvent(
      eventType: row['event_type']?.toString() ?? 'event',
      offsetMs: int.tryParse(row['event_offset_ms']?.toString() ?? '') ?? 0,
      payload: _asMap(row['payload']),
    );
  }

  String get kind => eventType.split('_').first;

  String get offsetLabel {
    final seconds = offsetMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  IconData get icon {
    return switch (kind) {
      'page' => Icons.menu_book_rounded,
      'pdf' => Icons.picture_as_pdf_rounded,
      'board' => Icons.draw_rounded,
      'notebook' => Icons.note_alt_rounded,
      _ => Icons.timeline_rounded,
    };
  }

  Color get color {
    return switch (kind) {
      'page' => Colors.blue,
      'pdf' => Colors.red,
      'board' => Colors.green,
      'notebook' => Colors.amber,
      _ => Colors.teal,
    };
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}
