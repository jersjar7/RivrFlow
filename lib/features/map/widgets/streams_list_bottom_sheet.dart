// lib/features/map/widgets/streams_list_bottom_sheet.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../models/visible_stream.dart';

/// Bottom sheet showing list of visible streams with search functionality
class StreamsListBottomSheet extends StatefulWidget {
  final List<VisibleStream> streams;
  final Function(VisibleStream) onStreamSelected;

  const StreamsListBottomSheet({
    super.key,
    required this.streams,
    required this.onStreamSelected,
  });

  @override
  State<StreamsListBottomSheet> createState() => _StreamsListBottomSheetState();
}

class _StreamsListBottomSheetState extends State<StreamsListBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<VisibleStream> _filteredStreams = [];

  @override
  void initState() {
    super.initState();
    _filteredStreams = widget.streams;
    _searchController.addListener(_filterStreams);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStreams() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _filteredStreams = widget.streams;
      } else {
        _filteredStreams = widget.streams.where((stream) {
          return stream.stationId.toLowerCase().contains(query) ||
              (stream.riverName?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  void _onStreamTap(VisibleStream stream) {
    Navigator.pop(context); // Close bottom sheet
    widget.onStreamSelected(stream); // Fly to stream
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // 75% of screen height
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildStreamsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              CupertinoIcons.list_bullet,
              color: CupertinoColors.systemBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Title and count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visible Streams',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                ),
                Text(
                  '${widget.streams.length} stream${widget.streams.length == 1 ? '' : 's'} in view',
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),

          // Close button
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Icon(
              CupertinoIcons.xmark_circle_fill,
              color: CupertinoColors.systemGrey3,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.search,
              color: CupertinoColors.systemGrey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CupertinoTextField(
                controller: _searchController,
                placeholder: 'Search by station ID...',
                decoration: null,
                style: const TextStyle(fontSize: 16),
                padding: EdgeInsets.zero,
              ),
            ),
            if (_searchController.text.isNotEmpty)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  _searchController.clear();
                },
                child: const Icon(
                  CupertinoIcons.clear_circled_solid,
                  color: CupertinoColors.systemGrey3,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamsList() {
    if (_filteredStreams.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Results count
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    '${_filteredStreams.length} result${_filteredStreams.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // List
          Expanded(
            child: ListView.separated(
              itemCount: _filteredStreams.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: CupertinoColors.separator),
              itemBuilder: (context, index) {
                final stream = _filteredStreams[index];
                return _buildStreamItem(stream);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamItem(VisibleStream stream) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      onPressed: () => _onStreamTap(stream),
      child: Row(
        children: [
          // Stream order icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppConstants.getStreamOrderColor(
                stream.streamOrder,
              ).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              AppConstants.getStreamOrderIcon(stream.streamOrder),
              color: AppConstants.getStreamOrderColor(stream.streamOrder),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),

          // Stream info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stream.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Station ${stream.stationId} • Order ${stream.streamOrder}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stream.coordinates,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.tertiaryLabel,
                    fontFamily: 'SF Mono', // Monospace for coordinates
                  ),
                ),
              ],
            ),
          ),

          // Arrow indicator
          const Icon(
            CupertinoIcons.location_fill,
            color: CupertinoColors.systemBlue,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty
                  ? CupertinoIcons.search
                  : CupertinoIcons.list_bullet,
              size: 48,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No streams found'
                  : 'No streams visible',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try a different search term'
                  : 'Zoom in or pan to see streams',
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.tertiaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show the streams list modal
void showStreamsListModal(
  BuildContext context, {
  required List<VisibleStream> streams,
  required Function(VisibleStream) onStreamSelected,
}) {
  showCupertinoModalPopup(
    context: context,
    builder: (context) => StreamsListBottomSheet(
      streams: streams,
      onStreamSelected: onStreamSelected,
    ),
  );
}
