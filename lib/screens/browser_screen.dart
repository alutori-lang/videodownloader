import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../models/download_item.dart';
import '../widgets/download_popup.dart';
import '../l10n/app_localizations.dart';

class BrowserScreen extends StatefulWidget {
  final String initialUrl;

  const BrowserScreen({super.key, required this.initialUrl});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? _webViewController;
  String _currentUrl = '';
  String _pageTitle = '';
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
  }

  /// Controlla se siamo su un sito supportato per il download
  bool _isSupportedSite(String url) {
    final supportedDomains = [
      'youtube.com',
      'youtu.be',
      'facebook.com',
      'fb.watch',
      'instagram.com',
      'tiktok.com',
      'twitter.com',
      'x.com',
      'vimeo.com',
      'dailymotion.com',
      'soundcloud.com',
      'spotify.com',
      'reddit.com',
      'pinterest.com',
      'tumblr.com',
      'twitch.tv',
    ];

    return supportedDomains.any((domain) => url.contains(domain));
  }

  /// Controlla se l'URL è una pagina video specifica (per download diretto)
  bool _isVideoUrl(String url) {
    final videoPatterns = [
      // YouTube - all variants
      'youtube.com/watch',
      'm.youtube.com/watch',
      'youtube.com/shorts',
      'm.youtube.com/shorts',
      'youtube.com/v/',
      'youtu.be/',
      'youtube.com/embed/',
      'v=', // YouTube video ID parameter
      // Facebook
      'facebook.com/watch',
      'facebook.com/reel',
      'facebook.com/video',
      'fb.watch',
      'm.facebook.com/watch',
      // Instagram
      'instagram.com/p/',
      'instagram.com/reel/',
      'instagram.com/reels/',
      'instagram.com/tv/',
      // TikTok
      'tiktok.com/@',
      'tiktok.com/t/',
      'vm.tiktok.com',
      // Twitter/X
      'twitter.com/status',
      'x.com/status',
      // Others
      'vimeo.com/',
      'dailymotion.com/video',
      'soundcloud.com/',
      'spotify.com/track',
      'reddit.com/r/',
      'twitch.tv/videos',
    ];

    return videoPatterns.any((pattern) => url.contains(pattern));
  }

  Future<void> _showDownloadPopup() async {
    // Prova a ottenere l'URL reale del video tramite JavaScript
    String videoUrl = _currentUrl;

    debugPrint('Download popup: Current URL is $videoUrl');

    // Controlla se siamo su una pagina video
    if (!_isVideoUrl(videoUrl)) {
      // Mostra errore se non siamo su una pagina video
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vai su un video per scaricarlo'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_webViewController != null && _currentUrl.contains('youtube')) {
      try {
        // Prova a ottenere l'URL canonico o il video ID dalla pagina
        final result = await _webViewController!.evaluateJavascript(source: '''
          (function() {
            // 1. Prova URL corrente se contiene v= o shorts/
            var url = window.location.href;
            if (url.includes('v=') || url.includes('/shorts/') || url.includes('youtu.be/')) {
              return url;
            }

            // 2. Prova canonical URL
            var canonical = document.querySelector('link[rel="canonical"]');
            if (canonical && canonical.href && canonical.href.includes('watch')) {
              return canonical.href;
            }

            // 3. Prova og:url
            var ogUrl = document.querySelector('meta[property="og:url"]');
            if (ogUrl && ogUrl.content && ogUrl.content.includes('watch')) {
              return ogUrl.content;
            }

            // 4. Prova a trovare video ID nel player (mobile YouTube)
            var videoId = null;

            // Cerca nei data attributes
            var player = document.querySelector('[data-video-id]');
            if (player) {
              videoId = player.getAttribute('data-video-id');
            }

            // Cerca negli script inline
            if (!videoId) {
              var pageSource = document.documentElement.innerHTML;
              var matches = pageSource.match(/"videoId"\\s*:\\s*"([A-Za-z0-9_-]{11})"/);
              if (matches) videoId = matches[1];
            }

            // Cerca nell'URL embedded
            if (!videoId) {
              var embeds = document.querySelectorAll('iframe[src*="youtube"]');
              for (var i = 0; i < embeds.length; i++) {
                var src = embeds[i].src;
                var m = src.match(/embed\\/([A-Za-z0-9_-]{11})/);
                if (m) {
                  videoId = m[1];
                  break;
                }
              }
            }

            if (videoId) return 'https://www.youtube.com/watch?v=' + videoId;

            // Fallback: URL corrente
            return url;
          })();
        ''');

        if (result != null && result.toString().isNotEmpty && result.toString() != 'null') {
          final extracted = result.toString().replaceAll('"', '');
          if (extracted.contains('v=') || extracted.contains('/shorts/') || extracted.contains('youtu.be/')) {
            videoUrl = extracted;
            debugPrint('Download popup: Extracted video URL: $videoUrl');
          }
        }
      } catch (e) {
        // Se fallisce, usa l'URL corrente
        debugPrint('Failed to get video URL: $e');
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DownloadPopup(
        url: videoUrl,
        title: _pageTitle.isNotEmpty ? _pageTitle : 'Video',
        onPlay: () {
          Navigator.pop(context);
          // Play in internal player
        },
        onDownload: (format, quality) {
          Navigator.pop(context);
          _startDownload(format, quality, videoUrl);
        },
      ),
    );
  }

  void _startDownload(String format, String quality, String videoUrl) {
    final provider = Provider.of<DownloadProvider>(context, listen: false);

    // Converte la qualità nel formato Cobalt (es. "1080p" -> "1080")
    final cobaltQuality = quality.replaceAll('p', '').replaceAll('kbps', '');

    // Avvia il download usando Cobalt API
    provider.startDownload(
      videoUrl: videoUrl,
      title: _pageTitle.isNotEmpty ? _pageTitle : 'Video',
      quality: cobaltQuality,
      audioOnly: format == 'mp3',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Browser Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: const Color(0xFFFFF7ED),
              child: Row(
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // URL Bar
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: Color(0xFF22C55E),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              Uri.parse(_currentUrl).host,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF666666),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Refresh Button
                  GestureDetector(
                    onTap: () => _webViewController?.reload(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress Bar
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: const Color(0xFFFFEDD5),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEA580C)),
                minHeight: 3,
              ),

            // WebView
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      useHybridComposition: true,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        _isLoading = true;
                        _currentUrl = url.toString();
                      });
                    },
                    onLoadStop: (controller, url) async {
                      setState(() {
                        _isLoading = false;
                        _currentUrl = url.toString();
                      });
                      final title = await controller.getTitle();
                      setState(() {
                        _pageTitle = title ?? '';
                      });
                    },
                    // IMPORTANTE: Cattura navigazione SPA (YouTube mobile)
                    onUpdateVisitedHistory: (controller, url, isReload) {
                      if (url != null) {
                        setState(() {
                          _currentUrl = url.toString();
                        });
                        debugPrint('URL updated (SPA): $_currentUrl');
                      }
                    },
                    onProgressChanged: (controller, progress) {
                      setState(() {
                        _progress = progress / 100;
                      });
                    },
                  ),

                  // Floating Download Button - Sempre visibile sui siti supportati
                  if (_isSupportedSite(_currentUrl))
                    Positioned(
                      bottom: 20,
                      right: 16,
                      child: GestureDetector(
                        onTap: _showDownloadPopup,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isVideoUrl(_currentUrl)
                                  ? [const Color(0xFFEA580C), const Color(0xFFF97316)]
                                  : [const Color(0xFFEA580C).withOpacity(0.7), const Color(0xFFF97316).withOpacity(0.7)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Download Progress Bar
            Consumer<DownloadProvider>(
              builder: (context, provider, _) {
                final activeDownloads = provider.activeDownloads;
                if (activeDownloads.isEmpty) {
                  return const SizedBox.shrink();
                }

                final item = activeDownloads.first;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEA580C),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.downloadedText} / ${item.fileSizeText}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            item.progressText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.progress,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Download Completed/Failed Banner
            Consumer<DownloadProvider>(
              builder: (context, provider, _) {
                final downloads = provider.downloads;
                if (downloads.isEmpty) return const SizedBox.shrink();

                final lastItem = downloads.first;
                if (lastItem.status == DownloadStatus.completed) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: const Color(0xFF22C55E),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Download completato: ${lastItem.title}',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (lastItem.status == DownloadStatus.failed) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: Colors.red,
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Server offline',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Apri cobalt.tools con l'URL del video
                            final encodedUrl = Uri.encodeComponent(lastItem.url);
                            _webViewController?.loadUrl(
                              urlRequest: URLRequest(
                                url: WebUri('https://cobalt.tools/?u=$encodedUrl'),
                              ),
                            );
                            provider.removeDownload(lastItem.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Scarica manualmente',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Bottom Navigation
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () async {
                      if (await _webViewController?.canGoBack() ?? false) {
                        _webViewController?.goBack();
                      }
                    },
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    color: const Color(0xFFEA580C),
                  ),
                  IconButton(
                    onPressed: () async {
                      if (await _webViewController?.canGoForward() ?? false) {
                        _webViewController?.goForward();
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_ios_rounded),
                    color: const Color(0xFFEA580C),
                  ),
                  IconButton(
                    onPressed: () {
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                      );
                    },
                    icon: const Icon(Icons.home_rounded),
                    color: const Color(0xFFEA580C),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
