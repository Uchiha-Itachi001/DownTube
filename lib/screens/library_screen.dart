import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';
import '../providers/app_state.dart';
import '../widgets/library_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _activeFilter = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  final _filters = ['All', 'Video', 'Audio'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final completed = AppState.instance.downloads
            .where((d) => d.status == DownloadStatus.done)
            .toList();

        List<DownloadItem> filtered;
        if (_activeFilter == 'Video') {
          filtered = completed.where((d) => !d.resolution.endsWith('k')).toList();
        } else if (_activeFilter == 'Audio') {
          filtered = completed.where((d) => d.resolution.endsWith('k')).toList();
        } else {
          filtered = completed;
        }

        final q = _searchCtrl.text.toLowerCase();
        if (q.isNotEmpty) {
          filtered = filtered
              .where((d) => d.title.toLowerCase().contains(q))
              .toList();
        }

        return Column(
          children: [
            _buildToolbar(completed.length),
            const SizedBox(height: AppColors.gap),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(completed.isEmpty)
                  : _buildGrid(filtered),
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
              color: AppColors.surface2,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.video_library_outlined, size: 26, color: AppColors.muted2),
          ),
          const SizedBox(height: 14),
          Text(
            noneDownloaded ? 'Your library is empty' : 'No results',
            style: AppTextStyles.outfit(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted),
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
        border: Border.all(color: AppColors.border),
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
              color: AppColors.greenDim,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$total items',
              style: AppTextStyles.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
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
                      fontSize: 13, color: AppColors.muted),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 10, right: 6),
                    child: Icon(Icons.search_rounded, size: 16, color: AppColors.muted),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  filled: true,
                  fillColor: AppColors.surface2,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(color: AppColors.green.withValues(alpha: 0.4)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.green : AppColors.surface2,
                      border: Border.all(
                        color: isActive
                            ? AppColors.green.withValues(alpha: 0.4)
                            : AppColors.border,
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
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded, size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    'Sort',
                    style: AppTextStyles.outfit(
                        fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<DownloadItem> items) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: AppColors.gap,
        crossAxisSpacing: AppColors.gap,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final isAudio = item.resolution.endsWith('k');
        return LibraryCard(
          title: item.title,
          meta: '${item.resolution} · ${item.format}',
          duration: '—',
          size: item.format,
          isAudio: isAudio,
          thumbnailUrl: item.thumbnailUrl,
        );
      },
    );
  }
}
