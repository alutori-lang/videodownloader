import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// Servizio di download con multiple API di fallback
/// Se una API fallisce, prova automaticamente la successiva
class DownloadService {
  final Dio _dio = Dio();

  // ============================================================
  // LISTA API COBALT - Istanze community funzionanti (Feb 2026)
  // Fonte: https://cobalt.directory/
  // ============================================================

  // Lista di istanze Cobalt pubbliche (aggiornata)
  static const List<String> _cobaltInstances = [
    // Community instances con alta disponibilità
    'https://cobalt.alpha.wolfy.love',      // 100% uptime
    'https://cobalt.omega.wolfy.love',      // 96% uptime
    'https://nuko-c.meowing.de',            // 96% uptime
    'https://subito-c.meowing.de',          // 79% uptime
    'https://grapefruit.clxxped.lol',       // 88% uptime
    'https://melon.clxxped.lol',            // 83% uptime
    'https://cobaltapi.squair.xyz',         // 83% uptime
    'https://api.qwkuns.me',                // 83% uptime
    'https://api.dl.woof.monster',          // 75% uptime
    'https://api.kektube.com',              // 70% uptime
    'https://cobaltapi.cjs.nz',             // 63% uptime
  ];

  Future<String> get _downloadPath async {
    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Download/QuickSave');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory.path;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/QuickSave');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir.path;
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isDenied) {
        final mediaStatus = await Permission.manageExternalStorage.request();
        return mediaStatus.isGranted;
      }
      return status.isGranted;
    }
    return true;
  }

  // ============================================================
  // SISTEMA FALLBACK - Prova tutte le API disponibili
  // ============================================================

  /// Ottiene il link di download provando tutte le API disponibili
  Future<Map<String, dynamic>?> getDownloadUrl({
    required String url,
    String quality = '1080',
    bool audioOnly = false,
  }) async {
    debugPrint('Cobalt: Trying to get download URL for: $url');

    for (final apiUrl in _cobaltInstances) {
      debugPrint('Cobalt: Trying server $apiUrl');

      final result = await _tryCobaltApi(
        apiUrl: apiUrl,
        videoUrl: url,
        quality: quality,
        audioOnly: audioOnly,
      );

      if (result != null && result['success'] == true) {
        debugPrint('Cobalt: Success with $apiUrl');
        return result;
      }

      debugPrint('Cobalt: Failed with $apiUrl, trying next...');
    }

    debugPrint('Cobalt: All servers failed');
    return {
      'success': false,
      'error': 'Tutti i server sono offline. Riprova più tardi.',
    };
  }

  /// Prova una singola istanza Cobalt API
  Future<Map<String, dynamic>?> _tryCobaltApi({
    required String apiUrl,
    required String videoUrl,
    required String quality,
    required bool audioOnly,
  }) async {
    try {
      // Endpoint POST /
      final endpoint = apiUrl.endsWith('/') ? apiUrl : '$apiUrl/';

      final response = await _dio.post(
        endpoint,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null && status < 500,
        ),
        data: jsonEncode({
          'url': videoUrl,
          'videoQuality': quality,
          'audioFormat': 'mp3',
          'downloadMode': audioOnly ? 'audio' : 'auto',
          'filenameStyle': 'basic',
        }),
      );

      debugPrint('Cobalt response from $apiUrl: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;

        // Status: tunnel, redirect, picker, error
        if (data['status'] == 'tunnel' || data['status'] == 'redirect' || data['status'] == 'stream') {
          return {
            'success': true,
            'downloadUrl': data['url'],
            'filename': data['filename'] ?? 'video',
            'server': apiUrl,
          };
        } else if (data['status'] == 'picker') {
          final picker = data['picker'] as List?;
          if (picker != null && picker.isNotEmpty) {
            return {
              'success': true,
              'downloadUrl': picker[0]['url'],
              'filename': 'video',
              'picker': picker,
              'server': apiUrl,
            };
          }
        } else if (data['status'] == 'error') {
          final errorMsg = data['error'] ?? data['text'] ?? 'Unknown error';
          debugPrint('Cobalt error: $errorMsg');
        }
      }

      return null;
    } catch (e) {
      debugPrint('Cobalt exception with $apiUrl: $e');
      return null;
    }
  }

  // ============================================================
  // DOWNLOAD FILE
  // ============================================================

  Future<void> downloadFile({
    required String url,
    required String fileName,
    required Function(int received, int total) onProgress,
    required Function(String filePath) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        onError('Permesso di storage negato');
        return;
      }

      final savePath = await _downloadPath;
      final cleanFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final filePath = '$savePath/$cleanFileName';

      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received, total);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 30),
          sendTimeout: const Duration(minutes: 5),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
      );

      onComplete(filePath);
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Processo completo con fallback automatico
  Future<void> downloadVideo({
    required String videoUrl,
    required String title,
    String quality = '1080',
    bool audioOnly = false,
    required Function(int received, int total) onProgress,
    required Function(String filePath) onComplete,
    required Function(String error) onError,
  }) async {
    // Step 1: Ottieni link (con fallback automatico)
    final result = await getDownloadUrl(
      url: videoUrl,
      quality: quality,
      audioOnly: audioOnly,
    );

    if (result == null || result['success'] != true) {
      onError(result?['error'] ?? 'Impossibile ottenere il link di download');
      return;
    }

    // Step 2: Scarica il file
    final extension = audioOnly ? 'mp3' : 'mp4';
    final fileName = '$title.$extension';

    await downloadFile(
      url: result['downloadUrl'],
      fileName: fileName,
      onProgress: onProgress,
      onComplete: onComplete,
      onError: onError,
    );
  }

  /// Ottiene informazioni sul video
  Future<Map<String, dynamic>?> getVideoInfo(String url) async {
    try {
      String? oembedUrl;

      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        oembedUrl = 'https://www.youtube.com/oembed?url=$url&format=json';
      } else if (url.contains('vimeo.com')) {
        oembedUrl = 'https://vimeo.com/api/oembed.json?url=$url';
      }

      if (oembedUrl != null) {
        final response = await _dio.get(oembedUrl);
        if (response.statusCode == 200) {
          return {
            'title': response.data['title'] ?? 'Video',
            'author': response.data['author_name'] ?? '',
            'thumbnail': response.data['thumbnail_url'] ?? '',
            'duration': '',
          };
        }
      }
    } catch (e) {
      // Ignora errori
    }

    return {
      'title': 'Video',
      'author': '',
      'thumbnail': '',
      'duration': '',
    };
  }

  // ============================================================
  // VERIFICA STATO API
  // ============================================================

  /// Controlla quali API sono online
  Future<List<Map<String, dynamic>>> checkApiStatus() async {
    final results = <Map<String, dynamic>>[];

    for (final apiUrl in _cobaltInstances) {
      try {
        final stopwatch = Stopwatch()..start();
        final response = await _dio.get(
          apiUrl,
          options: Options(
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        stopwatch.stop();

        results.add({
          'url': apiUrl,
          'online': response.statusCode == 200 || response.statusCode == 405,
          'latency': stopwatch.elapsedMilliseconds,
        });
      } catch (e) {
        results.add({
          'url': apiUrl,
          'online': false,
          'latency': -1,
        });
      }
    }

    return results;
  }
}
