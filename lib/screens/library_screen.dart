import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../widgets/library_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _activeFilter = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  final _filters = ['All', 'Video', 'Audio', 'Playlist'];

  // Mock library data
  final _items = const <_LibItem>[
    _LibItem('Full Stack App with Next.js 14', '@Fireship', '14:32', '245 MB', 'VIDEO'),
    _LibItem('Advanced TypeScript Patterns', '@ThePrimeagen', '42:18', '1.2 GB', 'VIDEO'),
    _LibItem('Lofi Hip Hop - Study Beats', '@ChilledCow', '3:24:00', '48 MB', 'AUDIO'),
    _LibItem('System Design Interview Guide', '@TechLead', '1:08:45', '890 MB', 'VIDEO'),
    _LibItem('Docker in 100 Seconds', '@Fireship', '2:14', '32 MB', 'VIDEO'),
    _LibItem('How Git Works Under the Hood', '@Fireship', '18:26', '189 MB', 'VIDEO'),
    _LibItem('React 19 Complete Guide', '@Academind', '2:45:30', '1.8 GB', 'VIDEO'),
    _LibItem('Synthwave Playlist', '@Retrowave', '1:12:00', '96 MB', 'AUDIO'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        const SizedBox(height: AppColors.gap),
        Expanded(
          child: _buildGrid(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
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
              '${_items.length} items',
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
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: AppColors.green.withOpacity(0.4)),
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
                            ? AppColors.green.withOpacity(0.4)
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
                  Icon(Icons.sort_rounded, size: 14, color: AppColors.muted),
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

  Widget _buildGrid() {
    final filtered = _activeFilter == 'All'
        ? _items
        : _items.where((i) => i.type.toUpperCase() == _activeFilter.toUpperCase()).toList();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: AppColors.gap,
        crossAxisSpacing: AppColors.gap,
        childAspectRatio: 0.78,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final item = filtered[i];
        return LibraryCard(
          title: item.title,
          meta: item.channel,
          duration: item.duration,
          size: item.size,
          isAudio: item.type == 'AUDIO',
        );
      },
    );
  }
}

class _LibItem {
  final String title;
  final String channel;
  final String duration;
  final String size;
  final String type;
  const _LibItem(this.title, this.channel, this.duration, this.size, this.type);
}
