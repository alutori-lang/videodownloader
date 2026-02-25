import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/download_provider.dart';
import '../models/download_item.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'I Miei Download',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                  Consumer<DownloadProvider>(
                    builder: (context, provider, _) {
                      if (provider.completedDownloads.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return GestureDetector(
                        onTap: () => provider.clearCompleted(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Downloads List
            Expanded(
              child: Consumer<DownloadProvider>(
                builder: (context, provider, _) {
                  if (provider.downloads.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.download_rounded,
                            size: 80,
                            color: const Color(0xFFEA580C).withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Nessun download',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF999999),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'I tuoi download appariranno qui',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFBBBBBB),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: provider.downloads.length,
                    itemBuilder: (context, index) {
                      final item = provider.downloads[index];
                      return _DownloadItemCard(
                        item: item,
                        onDelete: () => provider.removeDownload(item.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadItemCard extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback onDelete;

  const _DownloadItemCard({
    required this.item,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: item.format == 'mp3'
                    ? [const Color(0xFF4CAF50), const Color(0xFF388E3C)]
                    : [const Color(0xFFEA580C), const Color(0xFFF97316)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.format == 'mp3' ? Icons.music_note : Icons.videocam,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (item.status == DownloadStatus.downloading)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: item.progress,
                        backgroundColor: const Color(0xFFEEEEEE),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFEA580C),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.downloadedText} / ${item.fileSizeText}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${item.fileSizeText} • ${item.format.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
              ],
            ),
          ),

          // Actions
          if (item.status == DownloadStatus.completed) ...[
            IconButton(
              onPressed: () => OpenFilex.open(item.filePath),
              icon: const Icon(Icons.play_circle_fill, color: Color(0xFFEA580C)),
            ),
            IconButton(
              onPressed: () => Share.shareXFiles([XFile(item.filePath)]),
              icon: const Icon(Icons.share, color: Color(0xFF999999)),
            ),
          ] else if (item.status == DownloadStatus.failed) ...[
            const Icon(Icons.error_outline, color: Colors.red),
          ],
        ],
      ),
    );
  }
}
