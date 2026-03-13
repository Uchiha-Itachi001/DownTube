import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';
import '../providers/app_state.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';
import '../widgets/app_notification.dart';

enum _HistoryDateFilter { week, all }

enum _HistoryStatusFilter { all, done, error }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryDateFilter _filter = _HistoryDateFilter.all;
  _HistoryStatusFilter _statusFilter = _HistoryStatusFilter.all;
  DateTime? _pickedDate;

  // ---- filter helpers ----

  List<DownloadItem> _applyFilter(List<DownloadItem> all) {
    // 1. Date filter
    List<DownloadItem> result;
    if (_pickedDate != null) {
      result = all.where((d) {
        final dDay =
            DateTime(d.createdAt.year, d.createdAt.month, d.createdAt.day);
        return dDay == _pickedDate;
      }).toList();
    } else {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      result = switch (_filter) {
        _HistoryDateFilter.week => all
            .where((d) => d.createdAt
                .isAfter(todayStart.subtract(const Duration(days: 7))))
            .toList(),
        _HistoryDateFilter.all => all,
      };
    }
    // 2. Status filter
    return switch (_statusFilter) {
      _HistoryStatusFilter.done =>
        result.where((d) => d.status == DownloadStatus.done).toList(),
      _HistoryStatusFilter.error =>
        result.where((d) => d.status == DownloadStatus.error).toList(),
      _HistoryStatusFilter.all => result,
    };
  }

  Map<DateTime, List<DownloadItem>> _groupByDay(List<DownloadItem> items) {
    final map = <DateTime, List<DownloadItem>>{};
    for (final item in items) {
      final key = DateTime(
          item.createdAt.year, item.createdAt.month, item.createdAt.day);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.black,
            surface: AppColors.surface1,
            onSurface: AppColors.text,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: AppColors.surface1,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _pickedDate = picked);
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final allHistory = AppState.instance.downloads
            .where((d) =>
                (d.status == DownloadStatus.done ||
                    d.status == DownloadStatus.error) &&
                d.showInHistory)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final filtered = _applyFilter(allHistory);
        final done =
            allHistory.where((d) => d.status == DownloadStatus.done).length;
        final failed =
            allHistory.where((d) => d.status == DownloadStatus.error).length;

        return LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 750;
          if (narrow) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeaderCard(allHistory, filtered),
                  const SizedBox(height: AppColors.gap),
                  _buildHistoryList(filtered, shrinkWrap: true),
                  const SizedBox(height: AppColors.gap),
                  _buildTotalDownloads(done),
                  const SizedBox(height: AppColors.gap),
                  _buildAllTimeStats(done, failed),
                  const SizedBox(height: AppColors.gap),
                  _buildWeeklyChart(),
                ],
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildHeaderCard(allHistory, filtered),
                    const SizedBox(height: AppColors.gap),
                    Expanded(child: _buildHistoryList(filtered)),
                  ],
                ),
              ),
              const SizedBox(width: AppColors.gap),
              SizedBox(
                width: 260,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTotalDownloads(done),
                      const SizedBox(height: AppColors.gap),
                      _buildAllTimeStats(done, failed),
                      const SizedBox(height: AppColors.gap),
                      _buildWeeklyChart(),
                    ],
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildHeaderCard(
      List<DownloadItem> allHistory, List<DownloadItem> filtered) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Text(
                'Download History',
                style: AppTextStyles.syne(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${filtered.length} shown',
                  style: AppTextStyles.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const Spacer(),
              _ClearAllButton(hasHistory: allHistory.isNotEmpty, items: filtered),
            ],
          ),
          const SizedBox(height: 10),
          // Filter row
          Row(
            children: [
              // Date preset pills
              for (final (label, val) in [
                ('This Week', _HistoryDateFilter.week),
                ('All Time', _HistoryDateFilter.all),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterPill(
                    label: label,
                    isActive: _pickedDate == null && _filter == val,
                    onTap: () =>
                        setState(() {
                          _filter = val;
                          _pickedDate = null;
                        }),
                  ),
                ),
              // Date picker button
              _DatePickerBtn(
                picked: _pickedDate,
                onTap: () => _pickDate(context),
                onClear: () => setState(() => _pickedDate = null),
              ),
              const Spacer(),
              // Status filter pills
              for (final (label, val, color) in [
                ('All', _HistoryStatusFilter.all, AppColors.accent),
                ('Done', _HistoryStatusFilter.done, AppColors.accent),
                (
                  'Error',
                  _HistoryStatusFilter.error,
                  AppColors.red,
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _FilterPill(
                    label: label,
                    isActive: _statusFilter == val,
                    activeColor: color,
                    onTap: () => setState(() => _statusFilter = val),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<DownloadItem> history,
      {bool shrinkWrap = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: history.isEmpty
          ? _buildEmptyHistory()
          : _buildGroupedList(history, shrinkWrap: shrinkWrap),
    );
  }

  Widget _buildGroupedList(List<DownloadItem> history,
      {bool shrinkWrap = false}) {
    final grouped = _groupByDay(history);
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final rows = <Widget>[];
    var globalIndex = 0;
    for (final day in days) {
      rows.add(_HistoryDateHeader(date: day));
      final dayItems = grouped[day]!;
      for (int i = 0; i < dayItems.length; i++) {
        globalIndex++;
        rows.add(_HistoryTile(item: dayItems[i], index: globalIndex));
        if (i < dayItems.length - 1) {
          rows.add(const Divider(
              height: 1, color: AppColors.border, indent: 12, endIndent: 12));
        }
      }
    }

    return ListView(
      shrinkWrap: shrinkWrap,
      physics:
          shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(6),
      children: rows,
    );
  }

  Widget _buildEmptyHistory() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.accentDim,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent.withOpacity(0.30)),
              ),
              child: Center(
                child: Icon(Icons.history_rounded,
                    size: 26, color: AppColors.accent.withOpacity(0.70)),
              ),
            ),
            const SizedBox(height: 14),
            Text('No history yet',
                style: AppTextStyles.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
            const SizedBox(height: 5),
            Text('Completed downloads will appear here',
                style:
                    AppTextStyles.outfit(fontSize: 11, color: AppColors.muted2),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalDownloads(int done) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'TOTAL DOWNLOADS',
                style: AppTextStyles.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$done',
            style: AppTextStyles.syne(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'All time completed',
            style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTimeStats(int done, int failed) {
    final total = done + failed;
    final rate = total == 0 ? 0.0 : (done / total * 100);
    return SectionCard(
      title: 'SESSION SUMMARY',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: StatTile(
                      value: '$total', label: 'Total Downloads', unit: '')),
              const SizedBox(width: 8),
              Expanded(
                  child: StatTile(
                      value: '$done', label: 'Successful', unit: '')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child:
                      StatTile(value: '$failed', label: 'Failed', unit: '')),
              const SizedBox(width: 8),
              Expanded(
                  child: StatTile(
                      value: rate.toStringAsFixed(0),
                      label: 'Success Rate',
                      unit: '%')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final now = DateTime.now();
    // Count completed downloads per day for the last 7 days
    final counts = List<double>.filled(7, 0);
    for (final d in AppState.instance.downloads) {
      if (d.status != DownloadStatus.done && d.status != DownloadStatus.error) continue;
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(d.createdAt.year, d.createdAt.month, d.createdAt.day))
          .inDays;
      if (diff >= 0 && diff < 7) counts[6 - diff] += 1;
    }
    // Day labels: 6 days ago → today
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final labels = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return dayNames[day.weekday - 1];
    });
    final maxCount = counts.fold(0.0, (a, b) => math.max(a, b));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS WEEK',
            style: AppTextStyles.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          // Proportional bar chart
          SizedBox(
            height: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isToday  = i == 6;
                final norm     = maxCount > 0 ? counts[i] / maxCount : 0.0;
                final barH     = math.max(4.0, 64.0 * norm);
                final hasDownloads = counts[i] > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      height: barH,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                        color: isToday
                            ? AppColors.accent
                            : AppColors.accent.withOpacity(0.35),
                        boxShadow: isToday && hasDownloads
                            ? [BoxShadow(
                                color: AppColors.accentGlow,
                                blurRadius: 10,
                              )]
                            : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isToday = i == 6;
              final count   = counts[i].toInt();
              return Expanded(
                child: Column(
                  children: [
                    if (count > 0)
                      Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.outfit(
                          fontSize: 9,
                          color: isToday ? AppColors.accent : AppColors.muted2,
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: AppTextStyles.outfit(
                        fontSize: 10,
                        color: isToday ? AppColors.accent : AppColors.muted2,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// -- Date section header inside history list
class _HistoryDateHeader extends StatelessWidget {
  final DateTime date;
  const _HistoryDateHeader({required this.date});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static String _label(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'TODAY';
    if (date == yesterday) return 'YESTERDAY';
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          Text(
            _label(date),
            style: AppTextStyles.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: AppColors.border)),
        ],
      ),
    );
  }
}

// -- Small filter pill
class _FilterPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? activeColor;
  const _FilterPill(
      {required this.label,
      required this.isActive,
      required this.onTap,
      this.activeColor});

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.accent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.14) : Colors.transparent,
            border: Border.all(
              color: isActive
                  ? color.withOpacity(0.4)
                  : AppColors.accent.withOpacity(0.20),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: AppTextStyles.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isActive ? color : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// -- Date picker button
class _DatePickerBtn extends StatelessWidget {
  final DateTime? picked;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DatePickerBtn(
      {required this.picked, required this.onTap, required this.onClear});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String get _label => picked == null
      ? 'Pick date'
      : '${picked!.day} ${_months[picked!.month - 1]} ${picked!.year}';

  @override
  Widget build(BuildContext context) {
    final isActive = picked != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accent.withOpacity(0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: isActive
                      ? AppColors.accent.withOpacity(0.4)
                      : AppColors.accent.withOpacity(0.20),
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 11,
                      color: isActive ? AppColors.accent : AppColors.muted),
                  const SizedBox(width: 5),
                  Text(
                    _label,
                    style: AppTextStyles.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActive ? AppColors.accent : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isActive) ...[
          const SizedBox(width: 4),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onClear,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: AppColors.accent.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 11, color: AppColors.muted),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Clear All button 

class _ClearAllButton extends StatefulWidget {
  final bool hasHistory;
  final List<DownloadItem> items;
  const _ClearAllButton({required this.hasHistory, required this.items});

  @override
  State<_ClearAllButton> createState() => _ClearAllButtonState();
}

class _ClearAllButtonState extends State<_ClearAllButton> {
  bool _hovered = false;

  Future<void> _onClearAll() async {
    final count = widget.items.length;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, spreadRadius: 2)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.red.withOpacity(0.30)),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.red),
                  ),
                  const SizedBox(width: 12),
                  Text('Clear History',
                      style: AppTextStyles.outfit(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Remove $count item${count == 1 ? '' : 's'} from history?\n\nThis will permanently delete the associated files from your device.',
                style: AppTextStyles.outfit(fontSize: 13, color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: AppTextStyles.outfit(fontSize: 13, color: AppColors.muted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Clear',
                        style: AppTextStyles.outfit(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      for (final item in widget.items) {
        await AppState.instance.permanentlyDelete(item.id);
      }
      if (context.mounted) {
        showAppNotification(
          context,
          type: NotificationType.success,
          message: '$count item${count == 1 ? '' : 's'} cleared from history',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.hasHistory ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.hasHistory ? _onClearAll : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.hasHistory && _hovered
                ? AppColors.red.withOpacity(0.12)
                : Colors.transparent,
            border: Border.all(
              color: widget.hasHistory && _hovered
                  ? AppColors.red.withOpacity(0.4)
                  : AppColors.accent.withOpacity(0.20),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_sweep_rounded,
                size: 14,
                color: widget.hasHistory && _hovered ? AppColors.red : AppColors.muted,
              ),
              const SizedBox(width: 5),
              Text(
                'Clear All',
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  color: widget.hasHistory && _hovered ? AppColors.red : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// History tile 

class _HistoryTile extends StatefulWidget {
  final DownloadItem item;
  final int index;

  const _HistoryTile({required this.item, required this.index});

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  bool _hovered = false;

  static String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  /// Formats a full path to "parentFolder/filename.ext" for compact display.
  static String _shortPath(String p) {
    final parts = p.replaceAll('\\', '/').split('/');
    if (parts.length >= 2) return '${parts[parts.length - 2]}/${parts.last}';
    return parts.last;
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 2)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.30)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red),
                  ),
                  const SizedBox(width: 12),
                  Text('Delete Download',
                      style: AppTextStyles.outfit(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Delete "${widget.item.title}"?\n\nThis will remove it from history and permanently delete the file from your device.',
                style: AppTextStyles.outfit(
                    fontSize: 13, color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: AppTextStyles.outfit(
                            fontSize: 13, color: AppColors.muted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Delete',
                        style: AppTextStyles.outfit(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      await AppState.instance.permanentlyDelete(widget.item.id);
      if (mounted) {
        showAppNotification(
          context,
          type: NotificationType.success,
          message: 'Download deleted',
          subtitle: 'Removed from history and deleted from PC',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final success = item.status == DownloadStatus.done;
    final subtitle = '${item.resolution} · ${item.format}';
    final time = _relTime(item.createdAt);
    final isAudio = item.resolution.endsWith('k');
    final accent = isAudio ? const Color(0xFF3B82F6) : AppColors.accent;

    return GestureDetector(
      onDoubleTap: success ? () => _openFile(item) : null,
      child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surface2.withOpacity(0.4) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Index 
            SizedBox(
              width: 28,
              child: Text(
                widget.index.toString().padLeft(2, '0'),
                style: AppTextStyles.outfit(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted2),
              ),
            ),
            // Thumbnail 
            SizedBox(
              width: 72,
              height: 44,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: item.thumbnailUrl != null
                          ? Image.network(
                              item.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _fallbackThumb(accent, isAudio),
                            )
                          : _fallbackThumb(accent, isAudio),
                    ),
                  ),
                  if (_hovered && !success)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          color: Colors.black.withOpacity(0.82),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline_rounded, color: AppColors.red, size: 14),
                              const SizedBox(height: 2),
                              Text(
                                'Failed',
                                style: AppTextStyles.outfit(fontSize: 8, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_hovered && success)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          color: Colors.black.withOpacity(0.55),
                          child: Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white.withOpacity(0.9),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Title + meta 
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: success ? AppColors.text : AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        subtitle,
                        style: AppTextStyles.outfit(fontSize: 11.5, color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!success && item.errorMessage != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.errorMessage!,
                            style: AppTextStyles.outfit(
                                fontSize: 10, color: const Color(0xFFEF4444)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Partial file path for error videos
                  if (!success && item.filePath.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.folder_outlined, size: 10, color: AppColors.muted2),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _shortPath(item.filePath),
                            style: AppTextStyles.mono(
                              fontSize: 9,
                              color: AppColors.muted2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 1),
                  Text(
                    time,
                    style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Status pill 
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: success
                    ? AppColors.accentDim
                    : const Color(0xFFEF4444).withOpacity(0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: success
                      ? AppColors.accent.withOpacity(0.3)
                      : const Color(0xFFEF4444).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    success
                        ? (isAudio ? Icons.music_note_rounded : Icons.check_rounded)
                        : Icons.close_rounded,
                    size: 10,
                    color: success ? AppColors.accent : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    success ? 'Done' : 'Failed',
                    style: AppTextStyles.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: success ? AppColors.accent : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Delete action 
            AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.35,
              duration: const Duration(milliseconds: 150),
              child: _DeleteIconButton(onTap: _confirmDelete),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _openFile(DownloadItem item) {
    final path = item.filePath.isNotEmpty ? item.filePath : item.outputPath;
    if (path.isEmpty || !File(path).existsSync()) return;
    Process.run('cmd', ['/c', 'start', '', path]);
  }

  Widget _fallbackThumb(Color accent, bool isAudio) {
    return Container(
      color: accent.withOpacity(0.1),
      child: Center(
        child: Icon(
          isAudio ? Icons.music_note_rounded : Icons.movie_rounded,
          size: 18,
          color: accent.withOpacity(0.6),
        ),
      ),
    );
  }
}

class _DeleteIconButton extends StatefulWidget {
  final VoidCallback onTap;
  const _DeleteIconButton({required this.onTap});

  @override
  State<_DeleteIconButton> createState() => _DeleteIconButtonState();
}

class _DeleteIconButtonState extends State<_DeleteIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFFEF4444).withOpacity(0.15)
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFFEF4444).withOpacity(0.4)
                  : AppColors.border,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.delete_outline_rounded,
              size: 14,
              color: _hovered ? const Color(0xFFEF4444) : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

