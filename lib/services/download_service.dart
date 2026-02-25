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

  // Lista di istanze Cobalt pubbliche (aggiornata Feb 2026)
  // Fonte: https://cobalt.directory/ e https://instances.hyper.lol/
  static const List<String> _cobaltInstances = [
    // Istanze senza Turnstile (priorità alta)
    'https://capi.tieren.men',
    'https://cobalt.dev.kwiatekmiki.com',
    'https://api.cobalt.lol',
    'https://cobalt-api.kwiatekmiki.com',
    // Community instances
    'https://cobalt.alpha.wolfy.love',
    'https://cobalt.omega.wolfy.love',
    'https://nuko-c.meowing.de',
    'https://grapefruit.clxxped.lol',
    'https://melon.clxxped.lol',
    'https://cobaltapi.squair.xyz',
    'https://api.qwkuns.me',
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
    // Prova diversi endpoint per ogni istanza
    final endpoints = [
      apiUrl.endsWith('/') ? apiUrl : '$apiUrl/',
      '$apiUrl/api/json',
      '$apiUrl/api',
    ];

    for (final endpoint in endpoints) {
      final result = await _tryEndpoint(
        endpoint: endpoint,
        videoUrl: videoUrl,
        quality: quality,
        audioOnly: audioOnly,
      );
      if (result != null) return result;
    }

    return null;
  }

  Future<Map<String, dynamic>?> _tryEndpoint({
    required String endpoint,
    required String videoUrl,
    required String quality,
    required bool audioOnly,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (status) => status != null && status < 500,
        ),
        data: jsonEncode({
          'url': videoUrl,
          'videoQuality': quality,
          'audioFormat': 'mp3',
          'downloadMode': audioOnly ? 'audio' : 'auto',
          'filenameStyle': 'basic',
          // Vecchio formato (v6)
          'vQuality': quality,
          'aFormat': 'mp3',
          'isAudioOnly': audioOnly,
          'filenamePattern': 'basic',
        }),
      );

      debugPrint('Cobalt response from $endpoint: ${response.statusCode}');

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;

        // Status: tunnel, redirect, picker, stream, error
        final status = data['status']?.toString();
        if (status == 'tunnel' || status == 'redirect' || status == 'stream') {
          return {
            'success': true,
            'downloadUrl': data['url'],
            'filename': data['filename'] ?? 'video',
            'server': endpoint,
          };
        } else if (status == 'picker') {
          final picker = data['picker'] as List?;
          if (picker != null && picker.isNotEmpty) {
            var selectedItem = picker[0];
            for (final item in picker) {
              if (item['type'] == 'video') {
                selectedItem = item;
                break;
              }
            }
            return {
              'success': true,
              'downloadUrl': selectedItem['url'],
              'filename': 'video',
              'picker': picker,
              'server': endpoint,
            };
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Cobalt exception with $endpoint: $e');
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
