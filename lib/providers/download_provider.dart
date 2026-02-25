import 'package:flutter/foundation.dart';
import '../models/download_item.dart';
import '../services/download_service.dart';

class DownloadProvider extends ChangeNotifier {
  final List<DownloadItem> _downloads = [];
  final DownloadService _downloadService = DownloadService();

  List<DownloadItem> get downloads => List.unmodifiable(_downloads);

  List<DownloadItem> get completedDownloads =>
      _downloads.where((d) => d.status == DownloadStatus.completed).toList();

  List<DownloadItem> get activeDownloads =>
      _downloads.where((d) => d.status == DownloadStatus.downloading).toList();

  /// Scarica un video usando Cobalt API
  ///
  /// [videoUrl] - URL originale del video (YouTube, TikTok, ecc.)
  /// [title] - Titolo del video
  /// [quality] - Qualità: "1080", "720", "480", "360"
  /// [audioOnly] - Se true, scarica solo MP3
  Future<void> startDownload({
    required String videoUrl,
    required String title,
    String quality = '1080',
    bool audioOnly = false,
  }) async {
    final format = audioOnly ? 'mp3' : 'mp4';

    final item = DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      url: videoUrl,
      format: format,
      status: DownloadStatus.downloading,
    );

    _downloads.insert(0, item);
    notifyListeners();

    try {
      await _downloadService.downloadVideo(
        videoUrl: videoUrl,
        title: title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_'),
        quality: quality,
        audioOnly: audioOnly,
        onProgress: (received, total) {
          final index = _downloads.indexWhere((d) => d.id == item.id);
          if (index != -1) {
            _downloads[index].downloadedBytes = received;
            _downloads[index] = _downloads[index].copyWith(fileSize: total);
            notifyListeners();
          }
        },
        onComplete: (filePath) {
          final index = _downloads.indexWhere((d) => d.id == item.id);
          if (index != -1) {
            _downloads[index] = _downloads[index].copyWith(
              status: DownloadStatus.completed,
              filePath: filePath,
            );
            notifyListeners();
          }
        },
        onError: (error) {
          final index = _downloads.indexWhere((d) => d.id == item.id);
          if (index != -1) {
            _downloads[index] = _downloads[index].copyWith(
              status: DownloadStatus.failed,
            );
            notifyListeners();
          }
          debugPrint('Download error: $error');
        },
      );
    } catch (e) {
      final index = _downloads.indexWhere((d) => d.id == item.id);
      if (index != -1) {
        _downloads[index] = _downloads[index].copyWith(
          status: DownloadStatus.failed,
        );
        notifyListeners();
      }
      debugPrint('Download exception: $e');
    }
  }

  /// Metodo legacy per compatibilità
  Future<void> addDownload({
    required String url,
    required String title,
    required String format,
    String thumbnailUrl = '',
  }) async {
    await startDownload(
      videoUrl: url,
      title: title,
      audioOnly: format == 'mp3',
    );
  }

  void removeDownload(String id) {
    _downloads.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  void clearCompleted() {
    _downloads.removeWhere((d) => d.status == DownloadStatus.completed);
    notifyListeners();
  }

  /// Riprova un download fallito
  Future<void> retryDownload(String id) async {
    final index = _downloads.indexWhere((d) => d.id == id);
    if (index != -1) {
      final item = _downloads[index];
      _downloads.removeAt(index);
      await startDownload(
        videoUrl: item.url,
        title: item.title,
        audioOnly: item.format == 'mp3',
      );
    }
  }
}
