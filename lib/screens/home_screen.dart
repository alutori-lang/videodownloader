import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'browser_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();

  final List<Map<String, dynamic>> _platforms = [
    {'name': 'YouTube', 'icon': Icons.play_circle_fill, 'color': const Color(0xFFFF0000), 'url': 'https://www.youtube.com'},
    {'name': 'Facebook', 'icon': Icons.facebook, 'color': const Color(0xFF1877F2), 'url': 'https://www.facebook.com'},
    {'name': 'Instagram', 'icon': Icons.camera_alt, 'color': const Color(0xFFE4405F), 'url': 'https://www.instagram.com'},
    {'name': 'TikTok', 'icon': Icons.music_note, 'color': const Color(0xFF000000), 'url': 'https://www.tiktok.com'},
    {'name': 'Twitter', 'icon': Icons.alternate_email, 'color': const Color(0xFF1DA1F2), 'url': 'https://www.twitter.com'},
    {'name': 'Spotify', 'icon': Icons.audiotrack, 'color': const Color(0xFF1DB954), 'url': 'https://open.spotify.com'},
    {'name': 'Vimeo', 'icon': Icons.videocam, 'color': const Color(0xFF1AB7EA), 'url': 'https://www.vimeo.com'},
    {'name': 'SoundCloud', 'icon': Icons.cloud, 'color': const Color(0xFFFF5500), 'url': 'https://www.soundcloud.com'},
  ];

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _urlController.text = data.text!;
      });
    }
  }

  void _openBrowser(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrowserScreen(initialUrl: url),
      ),
    );
  }

  void _downloadFromUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      _openBrowser(url);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'QuickSave',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Paste URL Button
              GestureDetector(
                onTap: _pasteFromClipboard,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFDBA74),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.content_paste_rounded, color: Color(0xFFEA580C)),
                      SizedBox(width: 10),
                      Text(
                        'Incolla URL',
                        style: TextStyle(
                          color: Color(0xFFEA580C),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // URL Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _urlController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'Incolla qualsiasi URL del video o MP3...',
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(18),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Download Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _downloadFromUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFFEA580C).withValues(alpha: 0.4),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'SCARICA',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Divider
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: const Color(0xFFE5E5E5))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      'oppure',
                      style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: const Color(0xFFE5E5E5))),
                ],
              ),
              const SizedBox(height: 25),

              // Browse Section Title
              const Center(
                child: Text(
                  'Naviga e scarica direttamente',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Platforms Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.85,
                ),
                itemCount: _platforms.length,
                itemBuilder: (context, index) {
                  final platform = _platforms[index];
                  return GestureDetector(
                    onTap: () => _openBrowser(platform['url']),
                    child: Container(
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: platform['color'],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              platform['icon'],
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            platform['name'],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF666666),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
