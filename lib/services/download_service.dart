import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servizio di download con multiple API di fallback
/// Se una API fallisce, prova automaticamente la successiva
class DownloadService {
  final Dio _dio = Dio();

  // ============================================================
  // RAPIDAPI - YouTube Download (Free Tier: 100 req/mese)
  // Registrati su rapidapi.com per ottenere la tua API key
  // ============================================================

  // RapidAPI YouTube Download APIs
  static const String _rapidApiKey = 'd035b280a2mshd434ef0a92fe5a0p16241ejsn8190525f7a4e';

  // SMVD API - Social Media Video Downloader (ha URL PROXY che funzionano!)
  static const String _smvdHost = 'social-media-video-downloader.p.rapidapi.com';

  // Fallback RapidAPI hosts (URL diretti, possono dare 403)
  static const List<Map<String, String>> _rapidApiHosts = [
    {
      'host': 'ytstream-download-youtube-videos.p.rapidapi.com',
      'downloadEndpoint': '/dl',
      'videoParam': 'id',
      'useVideoId': 'true',
    },
  ];

  // ============================================================
  // COBALT INSTANCES - Backup servers
  // ============================================================

  static const List<String> _cobaltInstances = [
    'https://capi.tieren.men',
    'https://cobalt.dev.kwiatekmiki.com',
    'https://api.cobalt.lol',
    'https://cobalt-api.kwiatekmiki.com',
    'https://cobalt.alpha.wolfy.love',
    'https://cobalt.omega.wolfy.love',
    'https://nuko-c.meowing.de',
    'https://grapefruit.clxxped.lol',
    'https://melon.clxxped.lol',
  ];

  Future<String> get _downloadPath async {
    if (Platform.isAndroid) {
      // Prova prima la cartella Download pubblica
      try {
        final directory = Directory('/storage/emulated/0/Download/QuickSave');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        // Testa se possiamo scrivere
        final testFile = File('${directory.path}/.test');
        await testFile.writeAsString('test');
        await testFile.delete();
        return directory.path;
      } catch (e) {
        debugPrint('Cannot write to public Downloads, using app directory: $e');
      }
      // Fallback: cartella interna dell'app (non richiede permessi)
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/QuickSave');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir.path;
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
      // Android 13+ (API 33+): usa permessi media specifici
      // Android 11+ (API 30+): usa MANAGE_EXTERNAL_STORAGE
      // Android 10- (API 29-): usa WRITE_EXTERNAL_STORAGE

      // Prova MANAGE_EXTERNAL_STORAGE prima (per Android 11+)
      var manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) return true;

      // Prova storage generico
      var storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;

      // Prova permessi media (Android 13+)
      var videoStatus = await Permission.videos.request();
      if (videoStatus.isGranted) return true;

      // Se tutti i permessi sono negati, usiamo la cartella interna
      // che non richiede permessi - il download funzionerà comunque
      debugPrint('All storage permissions denied, will use app internal directory');
      return true; // Restituisci true - usiamo la cartella interna come fallback
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
    debugPrint('Download: Trying to get download URL for: $url');

    // 1. PRIMO: Prova SMVD (Social Media Video Downloader) - ha URL PROXY
    debugPrint('Download: Trying SMVD (proxy)...');
    final smvdResult = await _trySmvdApi(
      videoUrl: url,
      audioOnly: audioOnly,
    );
    if (smvdResult != null && smvdResult['success'] == true) {
      debugPrint('Download: Success with SMVD proxy!');
      return smvdResult;
    }

    // 2. Poi prova altre RapidAPI
    if (_rapidApiKey != 'YOUR_RAPIDAPI_KEY_HERE') {
      debugPrint('Download: Trying RapidAPI...');
      final rapidResult = await _tryRapidApi(
        videoUrl: url,
        audioOnly: audioOnly,
      );
      if (rapidResult != null && rapidResult['success'] == true) {
        debugPrint('Download: Success with RapidAPI');
        return rapidResult;
      }
    }

    // 2. Prova i server Cobalt
    for (final apiUrl in _cobaltInstances) {
      debugPrint('Download: Trying Cobalt server $apiUrl');

      final result = await _tryCobaltApi(
        apiUrl: apiUrl,
        videoUrl: url,
        quality: quality,
        audioOnly: audioOnly,
      );

      if (result != null && result['success'] == true) {
        debugPrint('Download: Success with $apiUrl');
        return result;
      }
    }

    debugPrint('Download: All servers failed');
    return {
      'success': false,
      'error': 'Tutti i server sono offline. Riprova più tardi.',
    };
  }

  /// Prova SMVD API - Social Media Video Downloader (URL PROXY!)
  /// Supporta YouTube, Facebook, Instagram, TikTok
  Future<Map<String, dynamic>?> _trySmvdApi({
    required String videoUrl,
    required bool audioOnly,
  }) async {
    try {
      // Determina endpoint e parametri in base alla piattaforma
      String? endpoint;
      Map<String, String> queryParams = {};

      if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
        // YouTube
        String? videoId;
        final uri = Uri.parse(videoUrl);
        if (videoUrl.contains('youtu.be/')) {
          videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.split('?').first : null;
        } else {
          videoId = uri.queryParameters['v'];
        }
        if (videoId == null || videoId.isEmpty) {
          debugPrint('SMVD: Could not extract YouTube video ID');
          return null;
        }
        endpoint = '/youtube/v3/video/details';
        queryParams = {
          'videoId': videoId,
          'renderableFormats': '360p,720p',
          'urlAccess': 'proxied',
          'getTranscript': 'false',
        };
      } else if (videoUrl.contains('facebook.com') || videoUrl.contains('fb.watch')) {
        // Facebook
        endpoint = '/facebook/v3/post/details';
        queryParams = {
          'url': videoUrl,
          'renderableFormats': '360p,720p',
          'urlAccess': 'proxied',
        };
      } else if (videoUrl.contains('instagram.com')) {
        // Instagram - estrai shortcode dall'URL
        String? shortcode;
        final regex = RegExp(r'instagram\.com/(?:p|reel|reels|tv)/([A-Za-z0-9_-]+)');
        final match = regex.firstMatch(videoUrl);
        if (match != null) {
          shortcode = match.group(1);
        }
        if (shortcode == null || shortcode.isEmpty) {
          debugPrint('SMVD: Could not extract Instagram shortcode');
          return null;
        }
        endpoint = '/instagram/v3/media/post/details';
        queryParams = {
          'shortcode': shortcode,
          'renderableFormats': '360p,720p',
        };
      } else if (videoUrl.contains('tiktok.com')) {
        // TikTok
        endpoint = '/tiktok/v3/post/details';
        queryParams = {
          'url': videoUrl,
          'renderableFormats': '360p,720p',
        };
      } else {
        debugPrint('SMVD: Unsupported platform for URL: $videoUrl');
        return null;
      }

      debugPrint('SMVD: Trying $endpoint for $videoUrl');

      final response = await _dio.get(
        'https://$_smvdHost$endpoint',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'x-rapidapi-key': _rapidApiKey,
            'x-rapidapi-host': _smvdHost,
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      debugPrint('SMVD: Status ${response.statusCode}');
      debugPrint('SMVD: Response keys: ${response.data is Map ? (response.data as Map).keys.toList() : 'not a map'}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        // Check for error response
        if (data['error'] != null) {
          debugPrint('SMVD: API error: ${data['error']}');
          return null;
        }

        String? downloadUrl;
        String? title = data['title'];

        // Formato diretto: url o video_url al top level
        if (data['url'] != null && data['url'] is String) {
          downloadUrl = data['url'];
        } else if (data['video_url'] != null) {
          downloadUrl = data['video_url'];
        } else if (data['download_url'] != null) {
          downloadUrl = data['download_url'];
        }

        // Prova campo 'links' (formato comune per Facebook)
        if (downloadUrl == null && data['links'] != null) {
          if (data['links'] is List && (data['links'] as List).isNotEmpty) {
            downloadUrl = (data['links'] as List).first['url']?.toString();
          } else if (data['links'] is Map) {
            final links = data['links'] as Map;
            downloadUrl = links['sd']?.toString() ?? links['hd']?.toString() ?? links['download']?.toString();
          }
        }

        // contents è un ARRAY, non un oggetto
        final contentsList = data['contents'];
        if (contentsList != null && contentsList is List && contentsList.isNotEmpty) {
          final contents = contentsList[0];

          // Audio - prova la migliore qualita' disponibile
          if (audioOnly && contents['audios'] != null) {
            final audios = contents['audios'] as List?;
            debugPrint('SMVD: audioOnly=true, audios count=${audios?.length ?? 0}');
            if (audios != null && audios.isNotEmpty) {
              // Preferisci audio con qualita' migliore (ultimo nella lista = migliore bitrate)
              // oppure usa il primo disponibile
              String? bestAudioUrl;
              int bestBitrate = 0;
              for (final audio in audios) {
                final audioUrl = audio['url']?.toString();
                if (audioUrl == null) continue;
                final bitrate = audio['metadata']?['bitrate'] as int? ?? 0;
                debugPrint('SMVD: Audio option: bitrate=$bitrate, quality=${audio['metadata']?['audio_quality']}');
                if (bitrate > bestBitrate || bestAudioUrl == null) {
                  bestBitrate = bitrate;
                  bestAudioUrl = audioUrl;
                }
              }
              downloadUrl = bestAudioUrl ?? audios.first['url'];
              debugPrint('SMVD: Selected audio URL, bitrate=$bestBitrate, length=${downloadUrl?.toString().length ?? 0}');
            }
          }

          // Video
          if (downloadUrl == null && contents['videos'] != null) {
            final videos = contents['videos'] as List?;
            if (videos != null && videos.isNotEmpty) {
              String? videoWithAudioUrl;
              String? videoOnlyUrl;
              String? audioOnlyUrl;

              for (final v in videos) {
                final url = v['url']?.toString();
                if (url == null) continue;

                // Controlla se ha audio integrato
                final hasAudio = v['metadata']?['has_audio'] == true ||
                    v['hasAudio'] == true ||
                    v['audioChannels'] != null ||
                    v['audioBitrate'] != null;

                // Controlla dal mimeType se e' muxed (video+audio)
                final mimeType = v['mimeType']?.toString() ?? v['metadata']?['mimeType']?.toString() ?? '';
                final isMuxed = mimeType.contains('video/mp4') && !mimeType.contains('codecs="avc');

                // Controlla qualita' - 360p e 720p progressive hanno audio
                final quality = v['quality']?.toString() ?? v['metadata']?['quality']?.toString() ?? '';
                final isLowQuality = quality.contains('360') || quality.contains('480') || quality.contains('720');

                if (hasAudio || isMuxed) {
                  videoWithAudioUrl = url;
                  break;
                } else if (isLowQuality && videoWithAudioUrl == null) {
                  // Le qualita' basse sono piu' probabili avere audio
                  videoWithAudioUrl = url;
                } else {
                  videoOnlyUrl ??= url;
                }
              }

              // Cerca anche audio separato da mixare dopo
              if (contents['audios'] != null) {
                final audios = contents['audios'] as List?;
                if (audios != null && audios.isNotEmpty) {
                  audioOnlyUrl = audios.first['url']?.toString();
                }
              }

              // Preferisci video con audio, altrimenti usa video-only
              downloadUrl = videoWithAudioUrl ?? videoOnlyUrl;

              debugPrint('SMVD: videoWithAudio=${videoWithAudioUrl != null}, videoOnly=${videoOnlyUrl != null}, audioOnly=${audioOnlyUrl != null}');
            }
          }

          title ??= contents['title'];
        }

        if (downloadUrl != null) {
          // Cerca audio separato se disponibile
          String? audioUrl;
          if (contentsList != null && contentsList is List && contentsList.isNotEmpty) {
            final firstContent = contentsList[0];
            if (firstContent != null && firstContent['audios'] != null) {
              final audios = firstContent['audios'] as List?;
              if (audios != null && audios.isNotEmpty) {
                audioUrl = audios.first['url']?.toString();
              }
            }
          }
          debugPrint('SMVD: SUCCESS - downloadUrl=${downloadUrl.substring(0, downloadUrl.length > 80 ? 80 : downloadUrl.length)}...');
          debugPrint('SMVD: audioUrl=${audioUrl != null ? "yes (${audioUrl.length} chars)" : "no"}');
          return {
            'success': true,
            'downloadUrl': downloadUrl,
            'audioUrl': audioUrl,
            'filename': title ?? 'video',
            'server': 'SMVD (proxy)',
          };
        }
      }

      return null;
    } catch (e) {
      debugPrint('SMVD exception: $e');
      return null;
    }
  }

  /// Prova RapidAPI YouTube Download con fallback su più host
  Future<Map<String, dynamic>?> _tryRapidApi({
    required String videoUrl,
    required bool audioOnly,
  }) async {
    // Estrai video ID dall'URL
    String? videoId;
    final uri = Uri.parse(videoUrl);

    if (videoUrl.contains('youtu.be/')) {
      videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
      // Rimuovi eventuali parametri dopo il video ID
      if (videoId != null && videoId.contains('?')) {
        videoId = videoId.split('?').first;
      }
    } else if (videoUrl.contains('youtube.com')) {
      videoId = uri.queryParameters['v'];
    }

    if (videoId == null || videoId.isEmpty) {
      debugPrint('RapidAPI: Could not extract video ID from URL: $videoUrl');
      return null;
    }

    debugPrint('RapidAPI: Extracted video ID: $videoId');

    // Prova tutti gli host RapidAPI disponibili
    for (final apiConfig in _rapidApiHosts) {
      final host = apiConfig['host']!;
      final endpoint = apiConfig['downloadEndpoint']!;
      final paramName = apiConfig['videoParam']!;
      final useFullUrl = apiConfig['useFullUrl'] == 'true';

      debugPrint('RapidAPI: Trying $host$endpoint');

      final result = await _tryRapidApiEndpoint(
        host: host,
        endpoint: endpoint,
        videoId: videoId,
        fullUrl: videoUrl,
        paramName: paramName,
        useFullUrl: useFullUrl,
        audioOnly: audioOnly,
      );

      if (result != null) {
        return result;
      }
    }

    return null;
  }

  /// Prova un singolo endpoint RapidAPI
  Future<Map<String, dynamic>?> _tryRapidApiEndpoint({
    required String host,
    required String endpoint,
    required String videoId,
    required String fullUrl,
    required String paramName,
    required bool useFullUrl,
    required bool audioOnly,
  }) async {
    try {
      // Usa URL completo o video ID in base alla configurazione dell'API
      final paramValue = useFullUrl ? fullUrl : videoId;

      final response = await _dio.get(
        'https://$host$endpoint',
        queryParameters: {paramName: paramValue},
        options: Options(
          headers: {
            'x-rapidapi-key': _rapidApiKey,
            'x-rapidapi-host': host,
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      debugPrint('RapidAPI $host: Status ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        debugPrint('RapidAPI $host: Response data type: ${response.data.runtimeType}');

        final downloadUrl = _extractDownloadUrl(response.data, audioOnly);
        if (downloadUrl != null) {
          final title = _extractTitle(response.data);
          debugPrint('RapidAPI $host: SUCCESS - Got download URL');
          return {
            'success': true,
            'downloadUrl': downloadUrl,
            'filename': title,
            'server': 'RapidAPI ($host)',
          };
        } else {
          debugPrint('RapidAPI $host: Could not extract download URL from response');
        }
      } else if (response.statusCode == 403) {
        debugPrint('RapidAPI $host: 403 Forbidden - API non sottoscritta o limite raggiunto');
      } else if (response.statusCode == 429) {
        debugPrint('RapidAPI $host: 429 Too Many Requests - Limite raggiunto');
      }

      return null;
    } catch (e) {
      debugPrint('RapidAPI $host exception: $e');
      return null;
    }
  }

  /// Estrae l'URL di download dal response API
  String? _extractDownloadUrl(dynamic data, bool audioOnly) {
    if (data == null) return null;

    // YTStream format: { status: "OK", formats: [...], adaptiveFormats: [...] }
    final status = data['status']?.toString().toLowerCase() ?? '';
    if (status == 'ok' || status == 'success') {
      // Prova adaptiveFormats per audio
      if (audioOnly && data['adaptiveFormats'] != null) {
        final adaptiveFormats = data['adaptiveFormats'] as List;
        for (final f in adaptiveFormats) {
          if (f['mimeType']?.toString().contains('audio') == true) {
            return f['url'];
          }
        }
      }

      // Prova formats per video
      if (data['formats'] != null && data['formats'] is List) {
        final formats = data['formats'] as List;
        // Cerca video con audio (720p o 360p di solito hanno audio)
        for (final f in formats) {
          if (f['url'] != null) {
            final hasAudio = f['hasAudio'] == true ||
                f['audioBitrate'] != null ||
                f['mimeType']?.toString().contains('video/mp4') == true;
            if (hasAudio || !audioOnly) {
              return f['url'];
            }
          }
        }
      }
    }

    // Formato 1: link diretto
    if (data['link'] != null) {
      if (audioOnly) {
        return data['link']['mp3'] ?? data['link']['audio'];
      } else {
        return data['link']['mp4'] ?? data['link']['video'];
      }
    }

    // Formato 2: URL diretto nel campo url
    if (data['url'] != null && data['url'] is String) {
      return data['url'];
    }

    // Formato 3: download_url (YouTube Video Download API style)
    if (data['download_url'] != null) {
      return data['download_url'];
    }

    // Formato 4: Array di formati generico
    if (data['formats'] != null && data['formats'] is List) {
      final formats = data['formats'] as List;
      String? bestUrl;
      int bestQuality = 0;

      for (final f in formats) {
        final mimeType = f['mimeType']?.toString() ?? '';
        final qualityLabel = f['qualityLabel']?.toString() ?? '';
        final quality = f['quality']?.toString() ?? '';

        // Estrai numero qualità (es. "720p" -> 720)
        int qualityNum = 0;
        final match = RegExp(r'(\d+)').firstMatch(qualityLabel);
        if (match != null) {
          qualityNum = int.tryParse(match.group(1) ?? '0') ?? 0;
        }

        if (audioOnly) {
          if (mimeType.contains('audio') && f['url'] != null) {
            return f['url'];
          }
        } else {
          // Per video, cerca la qualità migliore
          if (f['url'] != null && qualityNum > bestQuality) {
            bestQuality = qualityNum;
            bestUrl = f['url'];
          }
        }
      }

      if (bestUrl != null) return bestUrl;

      // Fallback: prendi il primo con URL
      for (final f in formats) {
        if (f['url'] != null) return f['url'];
      }
    }

    // Formato 5: streamingData (YouTube style)
    if (data['streamingData'] != null) {
      final formats = data['streamingData']['formats'] as List?;
      final adaptiveFormats = data['streamingData']['adaptiveFormats'] as List?;

      if (audioOnly && adaptiveFormats != null) {
        for (final format in adaptiveFormats) {
          if (format['mimeType']?.toString().contains('audio') == true) {
            return format['url'];
          }
        }
      }
      if (formats != null && formats.isNotEmpty) {
        return formats.first['url'];
      }
    }

    // Formato 6: videos array (YouTube Media Downloader style)
    if (data['videos'] != null && data['videos'] is List) {
      final videos = data['videos'] as List;
      if (videos.isNotEmpty) {
        for (final v in videos) {
          if (v['url'] != null) {
            return v['url'];
          }
        }
      }
    }

    // Formato 7: audios array
    if (audioOnly && data['audios'] != null && data['audios'] is List) {
      final audios = data['audios'] as List;
      if (audios.isNotEmpty && audios.first['url'] != null) {
        return audios.first['url'];
      }
    }

    // Formato 8: items array (alcuni API restituiscono così)
    if (data['items'] != null && data['items'] is List) {
      final items = data['items'] as List;
      if (items.isNotEmpty && items.first['url'] != null) {
        return items.first['url'];
      }
    }

    return null;
  }

  /// Estrae il titolo dal response API
  String _extractTitle(dynamic data) {
    if (data == null) return 'video';

    return data['title'] ??
        data['videoDetails']?['title'] ??
        data['info']?['title'] ??
        data['name'] ??
        'video';
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
      debugPrint('downloadFile: Starting download of $fileName');
      debugPrint('downloadFile: URL length=${url.length}, URL=${url.substring(0, url.length > 100 ? 100 : url.length)}...');

      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        onError('Permesso di storage negato');
        return;
      }

      final savePath = await _downloadPath;
      final cleanFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final filePath = '$savePath/$cleanFileName';

      debugPrint('downloadFile: Saving to $filePath');

      final response = await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received, total);
          } else {
            // Se total è sconosciuto, mostra almeno i bytes ricevuti
            onProgress(received, -1);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 30),
          sendTimeout: const Duration(minutes: 5),
          followRedirects: true,
          maxRedirects: 10,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 15; Pixel 8 Pro) AppleWebKit/537.36',
            'Accept': '*/*',
          },
        ),
      );

      debugPrint('downloadFile: Response status=${response.statusCode}');

      // Se il server ha restituito un errore HTTP 4xx
      if (response.statusCode != null && response.statusCode! >= 400) {
        debugPrint('downloadFile: HTTP error ${response.statusCode}');
        try { await File(filePath).delete(); } catch (_) {}
        onError('Errore HTTP ${response.statusCode} durante il download');
        return;
      }

      // Verifica che il file non sia una pagina di errore
      final file = File(filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize < 1000) {
          // File troppo piccolo - potrebbe essere una pagina di errore
          final content = await file.readAsString().catchError((_) => '');
          if (content.contains('<html') || content.contains('error')) {
            debugPrint('downloadFile: File is an error page ($fileSize bytes)');
            await file.delete();
            onError('Download fallito: il server ha restituito un errore');
            return;
          }
        }
        debugPrint('downloadFile: Download completed! $filePath ($fileSize bytes)');
      }

      onComplete(filePath);
    } on DioException catch (e) {
      debugPrint('downloadFile: DioException - type=${e.type}, statusCode=${e.response?.statusCode}, message=${e.message}');
      final statusCode = e.response?.statusCode;
      if (statusCode != null) {
        onError('Errore HTTP $statusCode durante il download');
      } else {
        onError('Errore di rete: ${e.type.name}');
      }
    } catch (e) {
      debugPrint('downloadFile: FAILED - $e');
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
    // Per audio-only: scarica video+audio e poi estrai solo audio
    // (il proxy SMVD da' 403 se scarichi audio direttamente)
    if (audioOnly) {
      debugPrint('Download: Audio-only requested, using video+audio merge+extract');
      final result = await getDownloadUrl(
        url: videoUrl,
        quality: quality,
        audioOnly: false, // Ottieni ENTRAMBI video e audio
      );

      if (result == null || result['success'] != true) {
        onError(result?['error'] ?? 'Impossibile ottenere il link di download');
        return;
      }

      final downloadUrl = result['downloadUrl'] as String?;
      final audioUrl = result['audioUrl'] as String?;

      if (downloadUrl == null || downloadUrl.isEmpty) {
        onError('URL di download vuoto');
        return;
      }

      // Usa download nativo Android per audio (bypassa Cloudflare TLS fingerprint)
      final audioDownloadUrl = audioUrl ?? downloadUrl;
      final cleanTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      await _downloadAudioNative(
        audioUrl: audioDownloadUrl,
        fileName: '$cleanTitle.m4a',
        onProgress: onProgress,
        onComplete: onComplete,
        onError: onError,
      );
      return;
    }

    // Step 1: Ottieni link (con fallback automatico)
    final result = await getDownloadUrl(
      url: videoUrl,
      quality: quality,
      audioOnly: false,
    );

    if (result == null || result['success'] != true) {
      onError(result?['error'] ?? 'Impossibile ottenere il link di download');
      return;
    }

    // Step 2: Scarica il file
    final fileName = '$title.mp4';
    final downloadUrl = result['downloadUrl'] as String?;

    debugPrint('Download: downloadUrl=${downloadUrl?.substring(0, 80)}..., fileName=$fileName');

    if (downloadUrl == null || downloadUrl.isEmpty) {
      onError('URL di download vuoto');
      return;
    }

    // Se c'e' audio separato, scarica entrambi e uniscili con MediaMuxer
    final audioUrl = result['audioUrl'] as String?;
    if (audioUrl != null) {
      debugPrint('Download: Video+Audio separati, scarico e unisco con MediaMuxer');
      await _downloadAndMerge(
        videoUrl: downloadUrl,
        audioUrl: audioUrl,
        fileName: fileName,
        onProgress: onProgress,
        onComplete: onComplete,
        onError: onError,
      );
      return;
    }

    debugPrint('Download: Downloading single file');
    await downloadFile(
      url: downloadUrl,
      fileName: fileName,
      onProgress: onProgress,
      onComplete: onComplete,
      onError: onError,
    );
  }

  static const _muxerChannel = MethodChannel('com.quicksave.quicksave_app/muxer');

  /// Scarica video e audio separatamente e li unisce con Android MediaMuxer
  Future<void> _downloadAndMerge({
    required String videoUrl,
    required String audioUrl,
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
      final ts = DateTime.now().millisecondsSinceEpoch;
      final tempVideoPath = '$savePath/.temp_video_$ts.mp4';
      final tempAudioPath = '$savePath/.temp_audio_$ts.m4a';
      final finalPath = '$savePath/$cleanFileName';

      final dlOptions = Options(
        receiveTimeout: const Duration(minutes: 30),
        sendTimeout: const Duration(minutes: 5),
        followRedirects: true,
        maxRedirects: 10,
        validateStatus: (status) => status != null && status < 400,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 15; Pixel 8 Pro) AppleWebKit/537.36',
          'Accept': '*/*',
        },
      );

      // 1. Scarica video (mostra progresso)
      debugPrint('Muxer: Downloading video...');
      await _dio.download(
        videoUrl,
        tempVideoPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress((received * 0.9).toInt(), total);
          } else {
            onProgress(received, -1);
          }
        },
        options: dlOptions,
      );

      // 2. Scarica audio (piccolo, veloce)
      debugPrint('Muxer: Downloading audio...');
      await _dio.download(
        audioUrl,
        tempAudioPath,
        options: dlOptions,
      );

      // 3. Unisci con Android MediaMuxer (nativo, velocissimo)
      debugPrint('Muxer: Merging video + audio...');
      final result = await _muxerChannel.invokeMethod<bool>('muxVideoAudio', {
        'videoPath': tempVideoPath,
        'audioPath': tempAudioPath,
        'outputPath': finalPath,
      });

      // 4. Pulizia file temporanei
      try { await File(tempVideoPath).delete(); } catch (_) {}
      try { await File(tempAudioPath).delete(); } catch (_) {}

      if (result == true) {
        debugPrint('Muxer: SUCCESS');
        onComplete(finalPath);
      } else {
        debugPrint('Muxer: FAILED');
        onError('Errore nel merge video+audio');
      }
    } catch (e) {
      debugPrint('Muxer exception: $e');
      onError(e.toString());
    }
  }

  /// Scarica un file usando il client HTTP nativo Android (bypassa Cloudflare TLS fingerprint)
  Future<void> _nativeDownloadFile({
    required String url,
    required String outputPath,
  }) async {
    debugPrint('NativeDownload: Downloading ${url.substring(0, url.length > 80 ? 80 : url.length)}...');
    debugPrint('NativeDownload: Output: $outputPath');

    final result = await _muxerChannel.invokeMethod<int>('nativeDownload', {
      'url': url,
      'outputPath': outputPath,
    });

    debugPrint('NativeDownload: Downloaded $result bytes');

    if (result == null || result <= 0) {
      throw Exception('Download nativo fallito: 0 bytes');
    }
  }

  /// Scarica audio usando download nativo Android (bypassa Cloudflare 403)
  /// Il proxy SMVD blocca Dart/Dio per TLS fingerprinting
  Future<void> _downloadAudioNative({
    required String audioUrl,
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
      final finalPath = '$savePath/$cleanFileName';

      // Mostra progresso indeterminato (il download nativo non supporta callback di progresso)
      onProgress(0, -1);

      // Scarica audio con client HTTP nativo Android
      debugPrint('AudioNative: Downloading audio with native HTTP client...');
      await _nativeDownloadFile(url: audioUrl, outputPath: finalPath);

      // Verifica che il file esista e sia valido
      final file = File(finalPath);
      if (await file.exists()) {
        final fileSize = await file.length();
        debugPrint('AudioNative: File size = $fileSize bytes');

        if (fileSize < 1000) {
          final content = await file.readAsString().catchError((_) => '');
          if (content.contains('<html') || content.contains('error') || content.contains('403')) {
            await file.delete();
            onError('Download fallito: il server ha restituito un errore');
            return;
          }
        }

        onProgress(fileSize, fileSize);
        debugPrint('AudioNative: SUCCESS - $finalPath ($fileSize bytes)');
        onComplete(finalPath);
      } else {
        onError('File non trovato dopo il download');
      }
    } catch (e) {
      debugPrint('AudioNative exception: $e');
      onError(e.toString());
    }
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
