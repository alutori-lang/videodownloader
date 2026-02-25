enum DownloadStatus { pending, downloading, completed, failed, paused }

class DownloadItem {
  final String id;
  final String title;
  final String url;
  final String thumbnailUrl;
  final String filePath;
  final String format;
  final int fileSize;
  int downloadedBytes;
  DownloadStatus status;
  final DateTime createdAt;

  DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnailUrl = '',
    this.filePath = '',
    this.format = 'mp4',
    this.fileSize = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.pending,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress {
    if (fileSize == 0) return 0;
    return downloadedBytes / fileSize;
  }

  String get progressText {
    return '${(progress * 100).toStringAsFixed(0)}%';
  }

  String get fileSizeText {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get downloadedText {
    if (downloadedBytes < 1024) return '$downloadedBytes B';
    if (downloadedBytes < 1024 * 1024) return '${(downloadedBytes / 1024).toStringAsFixed(1)} KB';
    return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  DownloadItem copyWith({
    String? id,
    String? title,
    String? url,
    String? thumbnailUrl,
    String? filePath,
    String? format,
    int? fileSize,
    int? downloadedBytes,
    DownloadStatus? status,
    DateTime? createdAt,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      fileSize: fileSize ?? this.fileSize,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class VideoFormat {
  final String quality;
  final String format;
  final int estimatedSize;
  final bool isAudioOnly;

  const VideoFormat({
    required this.quality,
    required this.format,
    required this.estimatedSize,
    this.isAudioOnly = false,
  });

  String get sizeText {
    if (estimatedSize < 1024) return '$estimatedSize B';
    if (estimatedSize < 1024 * 1024) return '${(estimatedSize / 1024).toStringAsFixed(0)} KB';
    return '${(estimatedSize / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  String get displayName {
    if (isAudioOnly) {
      return 'MP3 $quality';
    }
    return 'MP4 $quality';
  }
}
