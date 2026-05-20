import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/community_models.dart';
import '../../providers/community_providers.dart';
import '../../providers/user_data_provider.dart';

class ConversationDetailScreen extends ConsumerStatefulWidget {
  final int conversationId;
  final String title;
  final int? peerUserId;

  const ConversationDetailScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.peerUserId,
  });

  @override
  ConsumerState<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends ConsumerState<ConversationDetailScreen> {
  final _scrollCtrl = ScrollController();
  final _textCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    if (widget.peerUserId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(presenceProvider.notifier).refreshFor([widget.peerUserId!]);
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 100) {
      // Reverse list — scrolling toward top means we want older messages
      ref.read(messagesProvider(widget.conversationId).notifier).loadOlder();
    }
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textCtrl.clear();
    try {
      await ref.read(messagesProvider(widget.conversationId).notifier).sendText(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ส่งไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await picked.readAsBytes();
      await ref.read(messagesProvider(widget.conversationId).notifier).sendAttachment(
            bytes: bytes,
            fileName: picked.name,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ส่งรูปไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesProvider(widget.conversationId));
    final myUserId = ref.watch(userDataProvider).userId;
    final presence = widget.peerUserId == null ? null : ref.watch(presenceProvider)[widget.peerUserId];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            if (presence != null)
              Text(
                presence == PresenceStatus.online ? 'ออนไลน์' : 'ออฟไลน์',
                style: TextStyle(
                  fontSize: 12,
                  color: presence == PresenceStatus.online ? Colors.green.shade300 : Colors.white70,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(state, myUserId)),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageList(MessagesState state, int myUserId) {
    if (state.messages.isEmpty && state.isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.messages.isEmpty) {
      return const Center(child: Text('ส่งข้อความแรกของคุณ', style: TextStyle(color: Colors.grey)));
    }

    // Reverse list so newest sits at the bottom; scroll up loads older
    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: state.messages.length + (state.isLoadingHistory ? 1 : 0),
      itemBuilder: (_, i) {
        if (state.isLoadingHistory && i == state.messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        // reverse-index lookup
        final idx = state.messages.length - 1 - i;
        final msg = state.messages[idx];
        final isMine = msg.senderUserId != null && msg.senderUserId == myUserId;
        return _MessageBubble(msg: msg, isMine: isMine);
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.image_outlined),
              onPressed: _sending ? null : _pickAndSendImage,
              tooltip: 'ส่งรูปภาพ',
            ),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                decoration: const InputDecoration(
                  hintText: 'พิมพ์ข้อความ...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            IconButton(
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send, color: Color(0xFF628141)),
              onPressed: _sending ? null : _sendText,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMine;

  const _MessageBubble({required this.msg, required this.isMine});

  @override
  Widget build(BuildContext context) {
    if (msg.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(msg.body ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ),
      );
    }

    final bg = isMine ? const Color(0xFF628141) : Colors.grey.shade200;
    final fg = isMine ? Colors.white : Colors.black87;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: EdgeInsets.fromLTRB(isMine ? 60 : 12, 4, isMine ? 12 : 60, 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: align,
                children: [
                  if (msg.kind == 'image' && msg.attachmentUrl != null)
                    GestureDetector(
                      onTap: () => _openFullImage(context, msg.attachmentUrl!),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: Image.network(
                          msg.attachmentUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            padding: const EdgeInsets.all(12),
                            child: const Text('โหลดรูปไม่สำเร็จ', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    )
                  else if (msg.kind == 'file' && msg.attachmentUrl != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insert_drive_file, color: fg),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              msg.attachmentName ?? 'ไฟล์แนบ',
                              style: TextStyle(color: fg),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (msg.body != null && msg.body!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(msg.body!, style: TextStyle(color: fg, fontSize: 15)),
                    ),
                  if (msg.isDeleted)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Text('ข้อความถูกลบ', style: TextStyle(color: fg.withValues(alpha: 0.7), fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              DateFormat.Hm().format(msg.createdAt.toLocal()),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }
}
