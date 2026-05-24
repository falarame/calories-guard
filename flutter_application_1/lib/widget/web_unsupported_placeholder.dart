import 'package:flutter/material.dart';

/// Placeholder shown on Flutter web for screens that depend on mobile-only
/// plugins (Google Maps, geolocator, Samsung Health, etc.).
class WebUnsupportedPlaceholder extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const WebUnsupportedPlaceholder({
    super.key,
    this.title = 'ฟีเจอร์เฉพาะแอปมือถือ',
    this.message =
        'ฟีเจอร์นี้ใช้งานได้เฉพาะบนแอปมือถือ\nกรุณาดาวน์โหลดแอปเพื่อใช้งาน',
    this.icon = Icons.phone_android_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A2E0F)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF628141).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 56, color: const Color(0xFF628141)),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2E0F),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('ย้อนกลับ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF628141),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
