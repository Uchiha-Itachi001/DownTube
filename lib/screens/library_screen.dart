import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';
import '../providers/app_state.dart';
import '../widgets/library_card.dart';
import '../widgets/app_notification.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _activeFilter = 'All';
  final TextEditingController _searchCtrl = TextEditingController();
  DateTime? _selectedDate;

  final _filters = ['All', 'Video', 'Audio'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
      initialDate: _selectedDate ?? now,
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
          dialogTheme:
              const DialogThemeData(backgroundColor: AppColors.surface1),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final completed =
            AppState.instance.downloads
                .where(
                  (d) => d.status == DownloadStatus.done && d.showInLibrary,
                )
                .toList();

        List<DownloadItem> filtered;
        if (_activeFilter == 'Video') {
          filtered =
              completed.where((d) => !d.resolution.endsWith('k')).toList();
        } else if (_activeFilter == 'Audio') {
          filtered =
              completed.where((d) => d.resolution.endsWith('k')).toList();
        } else {
          filtered = completed;
        }

        final q = _searchCtrl.text.toLowerCase();
        if (q.isNotEmpty) {
          filtered =
              filtered.where((d) => d.title.toLowerCase().contains(q)).toList();
        }

        if (_selectedDate != null) {
          filtered = filtered.where((d) {
            final dDay = DateTime(
                d.createdAt.year, d.createdAt.month, d.createdAt.day);
            return dDay == _selectedDate;
          }).toList();
        }

        // Sort by newest first before grouping
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Column(
          children: [
            _buildToolbar(completed.length),
            const SizedBox(height: AppColors.gap),
            Expanded(
              child:
                  filtered.isEmpty
                      ? _buildEmptyState(completed.isEmpty)
                      : _buildGroupedGrid(filtered),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(bool noneDownloaded) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentDim,
              border: Border.all(color: AppColors.accent.withOpacity(0.30)),
            ),
            child: Icon(
              Icons.video_library_outlined,
              size: 26,
              color: AppColors.accent.withOpacity(0.70),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            noneDownloaded ? 'Your library is empty' : 'No results',
            style: AppTextStyles.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            noneDownloaded
                ? 'Completed downloads will appear here'
                : 'Try a different filter or search term',
            textAlign: TextAlign.center,
            style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted2),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Row(
        children: [
          Text(
            'My Library',
            style: AppTextStyles.syne(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$total items',
              style: AppTextStyles.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Search
          Flexible(
            flex: 3,
            child: SizedBox(
              height: 34,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: AppTextStyles.outfit(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search library...',
                  hintStyle: AppTextStyles.outfit(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 10, right: 6),
                    child: Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: AppColors.muted,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceTransparent,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.20)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.20)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Filters
          ...List.generate(_filters.length, (i) {
            final f = _filters[i];
            final isActive = _activeFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _activeFilter = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.accent : AppColors.surfaceTransparent,
                      border: Border.all(
                        color:
                            isActive
                                ? AppColors.accent.withValues(alpha: 0.4)
                                : AppColors.accent.withValues(alpha: 0.20),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      f,
                      style: AppTextStyles.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isActive ? Colors.black : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // Date filter button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _selectedDate != null
                      ? AppColors.accent.withOpacity(0.12)
                      : AppColors.surfaceTransparent,
                  border: Border.all(
                    color: _selectedDate != null
                        ? AppColors.accent.withOpacity(0.4)
                        : AppColors.accent.withOpacity(0.20),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: _selectedDate != null
                          ? AppColors.accent
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Date',
                      style: AppTextStyles.outfit(
                        fontSize: 12,
                        color: _selectedDate != null
                            ? AppColors.accent
                            : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_selectedDate != null) ...[const SizedBox(width: 4),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _selectedDate = null),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 12, color: AppColors.muted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupedGrid(List<DownloadItem> items) {
    final grouped = _groupByDay(items);
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final slivers = <Widget>[];
    for (final day in days) {
      slivers.add(SliverToBoxAdapter(
        child: _LibraryDateHeader(date: day),
      ));
      final dayItems = grouped[day]!;
      slivers.add(SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: AppColors.gap,
          crossAxisSpacing: AppColors.gap,
          mainAxisExtent: 245,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final item = dayItems[i];
            final isAudio = item.resolution.endsWith('k');
            return Stack(
              children: [
                LibraryCard(
                  title: item.title,
                  meta: '${item.resolution} · ${item.format}',
                  duration: item.formattedDuration,
                  size: formatFileSize(item.fileSize),
                  isAudio: isAudio,
                  thumbnailUrl: item.thumbnailUrl,
                  outputPath:
                      item.filePath.isNotEmpty ? item.filePath : item.outputPath,
                  onDoubleTap: () => _openFile(item),
                ),
                Positioned(
                  top: 16,
                  right: 8,
                  child: _DeleteBtn(onDelete: () => _confirmDelete(item)),
                ),
              ],
            );
          },
          childCount: dayItems.length,
        ),
      ));
      slivers.add(
          const SliverToBoxAdapter(child: SizedBox(height: AppColors.gap)));
    }

    return CustomScrollView(slivers: slivers);
  }

  void _openFile(DownloadItem item) async {
    final path = item.filePath.isNotEmpty ? item.filePath : item.outputPath;
    if (path.isEmpty) return;
    final uri = Uri.file(path);
    // Use url_launcher for reliable cross-platform file opening (handles
    // paths with spaces, parentheses, and other special characters correctly).
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback: try to open with explorer directly
      await Process.run('explorer', [path], runInShell: false);
    }
  }

  Future<void> _confirmDelete(DownloadItem item) async {
    final confirmed = await showDialog<bool>(
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
                'Delete "${item.title}"?\n\nThis will remove it from your library and permanently delete the file from your device.',
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
    if (confirmed == true && mounted) {
      await AppState.instance.permanentlyDelete(item.id);
      if (mounted) {
        showAppNotification(
          context,
          type: NotificationType.success,
          message: 'Deleted successfully',
          subtitle: item.title,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }
}

class _DeleteBtn extends StatefulWidget {
  final VoidCallback onDelete;
  const _DeleteBtn({required this.onDelete});

  @override
  State<_DeleteBtn> createState() => _DeleteBtnState();
}

class _DeleteBtnState extends State<_DeleteBtn> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onDelete,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hov
                ? AppColors.red.withOpacity(0.20)
                : Colors.black.withOpacity(0.60),
            border: Border.all(
              color: _hov
                  ? AppColors.red.withOpacity(0.60)
                  : Colors.white.withOpacity(0.15),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Icon(
              Icons.delete_outline_rounded,
              size: 14,
              color: _hov ? AppColors.red : Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

// Date section header for library grid
class _LibraryDateHeader extends StatelessWidget {
  final DateTime date;
  const _LibraryDateHeader({required this.date});

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
    return '${date.day} ${_months[date.month - 1]} ${date.year}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
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
