import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/user_data_provider.dart';
import '../../services/api_client.dart';
import '../../services/error_reporter.dart';

// ─── Message Model ────────────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final String? imageUrl;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
    this.imageUrl,
  }) : time = time ?? DateTime.now();
}

// ─── Quick Prompt suggestions ─────────────────────────────────────────────────
const _quickPrompts = [
  '📊 สรุปการกินวันนี้',
  '🍱 แนะนำเมนูมื้อเย็น',
  '🏃 วิ่ง 30 นาที เผาผลาญเท่าไหร่',
  '💪 โปรตีนวันนี้พอไหม',
  '⚖️ ความคืบหน้าน้ำหนัก',
];

// ─── Chat Screen ──────────────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _green = Color(0xFF628141);
  static const _greenDark = Color(0xFF3D5A27);
  static const _greenLight = Color(0xFFE8EFCF);
  static const _bg = Color(0xFFF5F7F0);

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  Position? _lastPosition;
  XFile? _pendingImage;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add(ChatMessage(
      text:
          'สวัสดีค่ะ! หนูคือน้องซีการ์ด 🌿\n\nผู้ช่วยดูแลสุขภาพส่วนตัวของคุณค่ะ '
          'ไม่ว่าจะเป็นเรื่องอาหาร แคลอรี่ การออกกำลังกาย หรือเป้าหมายน้ำหนัก '
          'น้องซีการ์ดพร้อมช่วยเสมอเลยนะคะ 😊\n\n'
          'วันนี้มีอะไรให้ช่วยคะ?',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Image Picker ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (picked != null && mounted) setState(() => _pendingImage = picked);
    } catch (e, st) {
      ErrorReporter.report('chat.pick_image', e, st);
    }
  }

  Future<String?> _uploadImage(XFile file) async {
    try {
      setState(() => _isUploadingImage = true);
      final bytes = await file.readAsBytes();
      final streamed = await ApiClient().uploadBytes(
        '/upload_image',
        fieldName: 'file',
        bytes: bytes,
        fileName: file.name,
      );
      if (streamed.statusCode == 200) {
        final body = await streamed.stream.bytesToString();
        final data = jsonDecode(body);
        return data['url'] as String? ?? data['image_url'] as String?;
      }
    } catch (e, st) {
      ErrorReporter.report('chat.upload_image', e, st);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
    return null;
  }

  // ─── Send Message ──────────────────────────────────────────────────────────

  Future<Position?> _getLocation() async {
    if (kIsWeb) return null; // geolocator ไม่รองรับ flutter web ในแอปนี้
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        return await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 5)));
      }
    } catch (e, st) {
      ErrorReporter.report('chat.get_location', e, st);
    }
    return null;
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    final imageFile = _pendingImage;
    if (msg.isEmpty && imageFile == null) return;
    if (_isTyping) return;

    _controller.clear();
    setState(() => _pendingImage = null);

    // Upload image first (before showing message)
    String? uploadedUrl;
    if (imageFile != null) {
      uploadedUrl = await _uploadImage(imageFile);
    }

    setState(() {
      _messages.add(ChatMessage(
        text: msg,
        isUser: true,
        imageUrl: uploadedUrl,
      ));
      _isTyping = true;
    });
    _scrollToBottom();

    final userId = ref.read(userDataProvider).userId;

    // ดึง location ถ้าข้อความเกี่ยวกับร้านอาหาร
    final isRestaurantQuery = msg.contains('ร้าน') ||
        msg.contains('ใกล้') ||
        msg.contains('restaurant') ||
        msg.contains('แนะนำร้าน');
    if (isRestaurantQuery || _lastPosition == null) {
      _lastPosition = await _getLocation();
    }

    final body = <String, dynamic>{'user_id': userId, 'message': msg};
    if (_lastPosition != null) {
      body['lat'] = _lastPosition!.latitude;
      body['lng'] = _lastPosition!.longitude;
    }
    if (uploadedUrl != null) body['image_url'] = uploadedUrl;

    try {
      final res = await ApiClient().post('/api/chat/multi', body: body);

      String reply;
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        reply = data['response'] as String? ?? 'ไม่มีคำตอบ';
      } else if (res.statusCode == 503) {
        reply = _aiUnavailableMessage;
      } else if (res.statusCode == 504) {
        reply = _aiTimeoutMessage;
      } else if (res.statusCode == 429) {
        reply = 'ตอนนี้ถาม AI ถี่เกินไปนิดหนึ่ง กรุณารอสักครู่แล้วลองใหม่ครับ';
      } else {
        reply = 'เกิดข้อผิดพลาด (${res.statusCode}) กรุณาลองใหม่ครับ';
      }

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: reply, isUser: false));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e, st) {
      ErrorReporter.report('chat.send', e, st);
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: _fallbackMessageFor(e),
            isUser: false,
          ));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  static const _aiUnavailableMessage =
      'ตอนนี้ AI Coach ยังไม่พร้อมใช้งาน แต่ฟีเจอร์หลักยังใช้ได้ปกติครับ '
      'คุณยังสามารถบันทึกอาหาร ดูแคลอรี่ น้ำ น้ำหนัก และคำแนะนำอาหารจากระบบได้';

  static const _aiTimeoutMessage =
      'AI ตอบช้าเกินไปครับ ลองถามใหม่แบบสั้นลง หรือกลับมาอีกครั้งภายหลัง';

  String _fallbackMessageFor(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('timed out') || text.contains('timeout')) {
      return _aiTimeoutMessage;
    }
    if (text.contains('network') ||
        text.contains('connection') ||
        text.contains('socket') ||
        text.contains('failed host lookup')) {
      return 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ครับ กรุณาตรวจอินเทอร์เน็ตแล้วลองใหม่ '
          'ส่วนการบันทึกอาหาร/น้ำ/น้ำหนักยังใช้งานต่อได้เมื่อกลับไปหน้าหลัก';
    }
    return _aiUnavailableMessage;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _messages.length) return _buildTypingIndicator();
              return _buildMessageBubble(_messages[i]);
            },
          ),
        ),
        _buildQuickPrompts(),
        _buildInputBar(),
      ]),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_greenDark, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        // Avatar
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Transform.scale(
              scale: 1.12,
              child: Image.asset(
                'assets/images/icon/chatbot_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('น้องซีการ์ด',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF2ECC71), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text('ผู้ช่วยดูแลสุขภาพ · พร้อมช่วยเหลือ',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8))),
              ]),
            ],
          ),
        ),
        // Info badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('AI',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ─── Message Bubble ────────────────────────────────────────────────────────

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: ClipOval(
                child: Transform.scale(
                  scale: 1.12,
                  child: Image.asset(
                    'assets/images/icon/chatbot_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _green : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        msg.imageUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    if (msg.text.isNotEmpty) const SizedBox(height: 6),
                  ],
                  if (msg.text.isNotEmpty)
                    Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: isUser ? Colors.white : Colors.black87,
                        height: 1.45,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? Colors.white.withOpacity(0.65)
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ─── Typing Indicator ──────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: ClipOval(
            child: Transform.scale(
              scale: 1.12,
              child: Image.asset(
                'assets/images/icon/chatbot_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _dot(0),
            const SizedBox(width: 4),
            _dot(200),
            const SizedBox(width: 4),
            _dot(400),
          ]),
        ),
      ]),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Opacity(
        opacity: v,
        child: Container(
          width: 8,
          height: 8,
          decoration:
              const BoxDecoration(color: _green, shape: BoxShape.circle),
        ),
      ),
    );
  }

  // ─── Quick Prompts ─────────────────────────────────────────────────────────

  Widget _buildQuickPrompts() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => _send(_quickPrompts[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _greenLight, width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Text(
              _quickPrompts[i],
              style: const TextStyle(
                  fontSize: 12, color: _greenDark, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Input Bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -3))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Pending image preview ──
        if (_pendingImage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_pendingImage!.path),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('รูปภาพพร้อมส่ง',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
              GestureDetector(
                onTap: () => setState(() => _pendingImage = null),
                child: Icon(Icons.close_rounded,
                    size: 20, color: Colors.grey.shade500),
              ),
            ]),
          ),
        Row(children: [
          // Image picker button
          GestureDetector(
            onTap: _isTyping || _isUploadingImage ? null : _pickImage,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _pendingImage != null
                    ? _green.withValues(alpha: 0.15)
                    : _bg,
                shape: BoxShape.circle,
                border: Border.all(color: _greenLight),
              ),
              child: _isUploadingImage
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _green))
                  : Icon(Icons.image_rounded,
                      size: 20,
                      color: _pendingImage != null ? _green : Colors.grey),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _greenLight),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _pendingImage != null
                      ? 'เพิ่มข้อความ (ไม่บังคับ)...'
                      : 'ถามน้องซีการ์ด...',
                  hintStyle:
                      TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: _send,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _send(_controller.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _isTyping ? Colors.grey.shade300 : _green,
                shape: BoxShape.circle,
                boxShadow: _isTyping
                    ? []
                    : [
                        BoxShadow(
                            color: _green.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
              ),
              child: Icon(
                _isTyping ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
