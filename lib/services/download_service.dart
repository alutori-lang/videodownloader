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
  // LISTA API COBALT - Istanze community funzionanti
  // ============================================================

  // Lista di istanze Cobalt pubbliche (aggiornata)
  static const List<Map<String, String>> _cobaltInstances = [
    // Istanze con nuovo formato API (v7+)
    {'url': 'https://cobalt.tools', 'version': 'v7'},
    {'url': 'https://cobalt-api.hyper.lol', 'version': 'v7'},
    {'url': 'https://cobalt.canine.tools', 'version': 'v7'},
    {'url': 'https://dl.khyernet.xyz', 'version': 'v7'},
    {'url': 'https://cobalt.lostdusty.win', 'version': 'v7'},
    // Istanze con vecchio formato (fallback)
    {'url': 'https://api.cobalt.tools/api/json', 'version': 'v6'},
    {'url': 'https://co.eepy.today/api/json', 'version': 'v6'},
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

    for (final instance in _cobaltInstances) {
      final apiUrl = instance['url']!;
      final version = instance['version']!;

      debugPrint('Cobalt: Trying server $apiUrl ($version)');

      final result = version == 'v7'
          ? await _tryApiV7(
              apiUrl: apiUrl,
              videoUrl: url,
              quality: quality,
              audioOnly: audioOnly,
            )
          : await _tryApiV6(
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

  /// Prova API Cobalt v7 (nuovo formato)
  Future<Map<String, dynamic>?> _tryApiV7({
    required String apiUrl,
    required String videoUrl,
    required String quality,
    required bool audioOnly,
  }) async {
    try {
      final endpoint = apiUrl.endsWith('/') ? apiUrl : '$apiUrl/';

      final response = await _dio.post(
        endpoint,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
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

      debugPrint('Cobalt v7 response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;

        // Nuovo formato v7
        if (data['status'] == 'tunnel' || data['status'] == 'redirect') {
          return {
            'success': true,
            'downloadUrl': data['url'],
            'filename': data['filename'] ?? 'video',
            'server': apiUrl,
          };
        } else if (data['status'] == 'picker') {
          final picker = data['picker'] as List;
          if (picker.isNotEmpty) {
            return {
              'success': true,
              'downloadUrl': picker[0]['url'],
              'filename': 'video',
              'picker': picker,
              'server': apiUrl,
            };
          }
        } else if (data['status'] == 'error') {
          debugPrint('Cobalt v7 error: ${data['error']}');
        }
      }

      return null;
    } catch (e) {
      debugPrint('Cobalt v7 exception: $e');
      return null;
    }
  }

  /// Prova API Cobalt v6 (vecchio formato)
  Future<Map<String, dynamic>?> _tryApiV6({
    required String apiUrl,
    required String videoUrl,
    required String quality,
    required bool audioOnly,
  }) async {
    try {
      final response = await _dio.post(
        apiUrl,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (status) => status != null && status < 500,
        ),
        data: jsonEncode({
          'url': videoUrl,
          'vQuality': quality,
          'aFormat': 'mp3',
          'isAudioOnly': audioOnly,
          'filenamePattern': 'basic',
        }),
      );

      debugPrint('Cobalt v6 response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['status'] == 'stream' || data['status'] == 'redirect') {
          return {
            'success': true,
            'downloadUrl': data['url'],
            'filename': data['filename'] ?? 'video',
            'server': apiUrl,
          };
        } else if (data['status'] == 'picker') {
          return {
            'success': true,
            'downloadUrl': data['picker'][0]['url'],
            'filename': 'video',
            'picker': data['picker'],
            'server': apiUrl,
          };
        } else if (data['status'] == 'error') {
          debugPrint('Cobalt v6 error: ${data['text']}');
        }
      }

      return null;
    } catch (e) {
      debugPrint('Cobalt v6 exception: $e');
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

    for (final instance in _cobaltInstances) {
      final apiUrl = instance['url']!;
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
