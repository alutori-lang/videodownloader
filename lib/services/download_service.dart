import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servizio di download con multiple API di fallback
/// Se una API fallisce, prova automaticamente la successiva
class DownloadService {
  final Dio _dio = Dio();

  // ============================================================
  // LISTA API DI BACKUP - Se una fallisce, prova la successiva
  // ============================================================

  // API 1: Cobalt (Principale)
  static const String _cobaltApi = 'https://api.cobalt.tools/api/json';

  // API 2: Istanze Cobalt alternative (community-hosted)
  static const List<String> _cobaltMirrors = [
    'https://cobalt.api.timelessnesses.me/api/json',
    'https://co.eepy.today/api/json',
  ];

  // API 3: AllTube (self-hosted alternativo)
  // Se vuoi hostare il tuo: https://github.com/Rudloff/alltube

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
    // Lista di tutte le API da provare in ordine
    final allApis = [_cobaltApi, ..._cobaltMirrors];

    for (final apiUrl in allApis) {
      final result = await _tryApi(
        apiUrl: apiUrl,
        videoUrl: url,
        quality: quality,
        audioOnly: audioOnly,
      );

      if (result != null && result['success'] == true) {
        return result; // Trovato! Restituisci il risultato
      }

      // Se fallisce, prova la prossima API
    }

    // Tutte le API hanno fallito
    return {
      'success': false,
      'error': 'Tutti i server sono offline. Riprova più tardi.',
    };
  }

  /// Prova una singola API Cobalt
  Future<Map<String, dynamic>?> _tryApi({
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
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        data: jsonEncode({
          'url': videoUrl,
          'vQuality': quality,
          'aFormat': 'mp3',
          'isAudioOnly': audioOnly,
          'filenamePattern': 'basic',
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['status'] == 'stream' || data['status'] == 'redirect') {
          return {
            'success': true,
            'downloadUrl': data['url'],
            'filename': data['filename'] ?? 'video',
            'server': apiUrl, // Traccia quale server ha funzionato
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
          return {
            'success': false,
            'error': data['text'] ?? 'Errore dal server',
          };
        }
      }

      return null; // Risposta non valida, prova prossima API
    } catch (e) {
      return null; // Errore, prova prossima API
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
    final allApis = [_cobaltApi, ..._cobaltMirrors];
    final results = <Map<String, dynamic>>[];

    for (final api in allApis) {
      try {
        final stopwatch = Stopwatch()..start();
        final response = await _dio.get(
          api.replaceAll('/api/json', '/api/serverInfo'),
          options: Options(
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        stopwatch.stop();

        results.add({
          'url': api,
          'online': response.statusCode == 200,
          'latency': stopwatch.elapsedMilliseconds,
        });
      } catch (e) {
        results.add({
          'url': api,
          'online': false,
          'latency': -1,
        });
      }
    }

    return results;
  }
}
