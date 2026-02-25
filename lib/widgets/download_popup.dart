import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class DownloadPopup extends StatefulWidget {
  final String url;
  final String title;
  final VoidCallback onPlay;
  final Function(String format, String quality) onDownload;

  const DownloadPopup({
    super.key,
    required this.url,
    required this.title,
    required this.onPlay,
    required this.onDownload,
  });

  @override
  State<DownloadPopup> createState() => _DownloadPopupState();
}

class _DownloadPopupState extends State<DownloadPopup> {
  bool _showFormats = false;
  String _selectedFormat = 'mp4';
  String _selectedQuality = '1080p';

  final List<Map<String, dynamic>> _videoFormats = [
    {'quality': '1080p', 'format': 'mp4', 'size': '~45 MB', 'desc': 'Full HD'},
    {'quality': '720p', 'format': 'mp4', 'size': '~28 MB', 'desc': 'HD'},
    {'quality': '480p', 'format': 'mp4', 'size': '~15 MB', 'desc': 'SD'},
  ];

  final List<Map<String, dynamic>> _audioFormats = [
    {'quality': '320kbps', 'format': 'mp3', 'size': '~8 MB', 'desc': 'High quality'},
    {'quality': '128kbps', 'format': 'mp3', 'size': '~3 MB', 'desc': 'Standard'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: _showFormats ? _buildFormatSelector() : _buildActionSelector(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSelector() {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // Video Thumbnail
        Row(
          children: [
            Container(
              width: 100,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF333333), Color(0xFF666666)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.video} detected',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Play Option
        _buildOptionButton(
          icon: Icons.play_circle_rounded,
          title: l10n.play,
          subtitle: 'Watch in player',
          isDownload: false,
          onTap: widget.onPlay,
        ),
        const SizedBox(height: 12),

        // Download Option
        _buildOptionButton(
          icon: Icons.download_rounded,
          title: l10n.downloadNow,
          subtitle: 'Save to device',
          isDownload: true,
          onTap: () => setState(() => _showFormats = true),
        ),
      ],
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDownload,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDownload
              ? const Color(0xFFEA580C)
              : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDownload
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDownload ? Colors.white : const Color(0xFFEA580C),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDownload ? Colors.white : const Color(0xFF333333),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDownload
                        ? Colors.white.withOpacity(0.8)
                        : const Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatSelector() {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back Button
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _showFormats = false),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFFEA580C)),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.format,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Video Formats
        Text(
          l10n.video,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 12),
        ..._videoFormats.map((format) => _buildFormatOption(format)),

        const SizedBox(height: 20),

        // Audio Formats
        Text(
          l10n.audio,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 12),
        ..._audioFormats.map((format) => _buildFormatOption(format)),

        const SizedBox(height: 24),

        // Download Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onDownload(_selectedFormat, _selectedQuality),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.download_rounded),
                const SizedBox(width: 10),
                Text(
                  '${l10n.download} ${_selectedFormat.toUpperCase()} $_selectedQuality',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatOption(Map<String, dynamic> format) {
    final isSelected = _selectedFormat == format['format'] &&
        _selectedQuality == format['quality'];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFormat = format['format'];
          _selectedQuality = format['quality'];
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE0E0E0),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFDDDDDD),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${format['format'].toString().toUpperCase()} ${format['quality']}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Text(
                    format['desc'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              format['size'],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEA580C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
