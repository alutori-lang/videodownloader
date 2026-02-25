import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
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
      'youtube.com/watch',
      'youtube.com/shorts',
      'youtu.be/',
      'facebook.com/watch',
      'facebook.com/reel',
      'fb.watch',
      'instagram.com/p/',
      'instagram.com/reel/',
      'instagram.com/reels/',
      'tiktok.com/@',
      'tiktok.com/t/',
      'twitter.com/status',
      'x.com/status',
      'vimeo.com/',
      'dailymotion.com/video',
      'soundcloud.com/',
      'spotify.com/track',
      'reddit.com/r/',
      'twitch.tv/videos',
    ];

    return videoPatterns.any((pattern) => url.contains(pattern));
  }

  void _showDownloadPopup() {
    final l10n = AppLocalizations.of(context);

    // Controlla se siamo su una pagina video specifica
    if (!_isVideoUrl(_currentUrl)) {
      // Mostra messaggio di aiuto
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📌 ${l10n.goToVideo}'),
          backgroundColor: const Color(0xFFEA580C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DownloadPopup(
        url: _currentUrl,
        title: _pageTitle.isNotEmpty ? _pageTitle : 'Video',
        onPlay: () {
          Navigator.pop(context);
          // Play in internal player
        },
        onDownload: (format, quality) {
          Navigator.pop(context);
          _startDownload(format, quality);
        },
      ),
    );
  }

  void _startDownload(String format, String quality) {
    final l10n = AppLocalizations.of(context);
    final provider = Provider.of<DownloadProvider>(context, listen: false);

    // Mostra snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.downloadStarted}: $_pageTitle'),
        backgroundColor: const Color(0xFFEA580C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Converte la qualità nel formato Cobalt (es. "1080p" -> "1080")
    final cobaltQuality = quality.replaceAll('p', '').replaceAll('kbps', '');

    // Avvia il download usando Cobalt API
    provider.startDownload(
      videoUrl: _currentUrl,
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
