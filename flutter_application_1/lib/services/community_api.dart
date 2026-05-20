import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/community_models.dart';
import 'api_client.dart';

/// Thin facade over [ApiClient] for community endpoints.
///
/// Every method throws [CommunityApiException] on non-2xx to give callers
/// (and Riverpod's AsyncError) a structured error to render.
class CommunityApi {
  CommunityApi._();
  static final CommunityApi instance = CommunityApi._();

  final ApiClient _api = ApiClient();

  // ── Referral ─────────────────────────────────────────────────────────────

  Future<ReferralSummary> getMyReferral() async {
    final r = await _api.get('/referral/me');
    _ensureOk(r, 'get referral');
    return ReferralSummary.fromJson(_decodeMap(r));
  }

  Future<List<InviteePreview>> getInvitees() async {
    final r = await _api.get('/referral/invitees');
    _ensureOk(r, 'list invitees');
    return _decodeList(r).map(InviteePreview.fromJson).toList();
  }

  Future<Map<String, dynamic>> sendEmailInvite(String email) async {
    final r = await _api.post('/referral/invite/email', body: {'email': email});
    _ensureOk(r, 'send email invite');
    return _decodeMap(r);
  }

  Future<ReferralPreview> previewReferral(String value) async {
    final r = await _api.get('/referral/preview/$value');
    _ensureOk(r, 'preview referral');
    return ReferralPreview.fromJson(_decodeMap(r));
  }

  // ── Friends ──────────────────────────────────────────────────────────────

  Future<List<FriendEntry>> listFriends() async {
    final r = await _api.get('/friends');
    _ensureOk(r, 'list friends');
    return _decodeList(r).map(FriendEntry.fromJson).toList();
  }

  Future<List<FriendEntry>> listFriendRequests() async {
    final r = await _api.get('/friends/requests');
    _ensureOk(r, 'list friend requests');
    return _decodeList(r).map(FriendEntry.fromJson).toList();
  }

  Future<Map<String, dynamic>> requestFriend(int userId) async {
    final r = await _api.post('/friends/request', body: {'user_id': userId});
    _ensureOk(r, 'request friend');
    return _decodeMap(r);
  }

  Future<Map<String, dynamic>> acceptFriend(int userId) async {
    final r = await _api.post('/friends/$userId/accept');
    _ensureOk(r, 'accept friend');
    return _decodeMap(r);
  }

  Future<void> removeFriend(int userId) async {
    final r = await _api.delete('/friends/$userId');
    _ensureOk(r, 'remove friend');
  }

  Future<void> blockUser(int userId) async {
    final r = await _api.post('/friends/$userId/block');
    _ensureOk(r, 'block user');
  }

  // ── Conversations ────────────────────────────────────────────────────────

  Future<List<ConversationSummary>> listConversations() async {
    final r = await _api.get('/conversations');
    _ensureOk(r, 'list conversations');
    return _decodeList(r).map(ConversationSummary.fromJson).toList();
  }

  Future<int> createDm(int otherUserId) async {
    final r = await _api.post('/conversations/dm', body: {'user_id': otherUserId});
    _ensureOk(r, 'create DM');
    final m = _decodeMap(r);
    return (m['conversation_id'] as num).toInt();
  }

  Future<int> createGroup(String name, List<int> memberUserIds) async {
    final r = await _api.post('/conversations/group', body: {
      'name': name,
      'member_user_ids': memberUserIds,
    });
    _ensureOk(r, 'create group');
    return (_decodeMap(r)['conversation_id'] as num).toInt();
  }

  Future<Map<String, dynamic>> getConversation(int conversationId) async {
    final r = await _api.get('/conversations/$conversationId');
    _ensureOk(r, 'get conversation');
    return _decodeMap(r);
  }

  // ── Messages ─────────────────────────────────────────────────────────────

  Future<List<ChatMessage>> listMessages(int conversationId, {int? before, int limit = 50}) async {
    final params = <String, String>{'limit': '$limit'};
    if (before != null) params['before'] = '$before';
    final r = await _api.get('/conversations/$conversationId/messages', queryParams: params);
    _ensureOk(r, 'list messages');
    return _decodeList(r).map(ChatMessage.fromJson).toList();
  }

  Future<ChatMessage> sendMessage(
    int conversationId, {
    String kind = 'text',
    String? body,
    String? attachmentUrl,
    String? attachmentMime,
    int? attachmentSize,
    String? attachmentName,
    int? replyToMessageId,
  }) async {
    final r = await _api.post(
      '/conversations/$conversationId/messages',
      body: {
        'kind': kind,
        if (body != null) 'body': body,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        if (attachmentMime != null) 'attachment_mime': attachmentMime,
        if (attachmentSize != null) 'attachment_size': attachmentSize,
        if (attachmentName != null) 'attachment_name': attachmentName,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      },
    );
    _ensureOk(r, 'send message');
    return ChatMessage.fromJson(_decodeMap(r));
  }

  Future<void> deleteMessage(int messageId) async {
    final r = await _api.delete('/messages/$messageId');
    _ensureOk(r, 'delete message');
  }

  Future<void> markRead(int conversationId, int messageId) async {
    final r = await _api.post('/conversations/$conversationId/read', body: {'message_id': messageId});
    _ensureOk(r, 'mark read');
  }

  // ── Uploads ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadAttachment({
    required int conversationId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final streamed = await _api.uploadBytes(
      '/uploads/chat',
      fieldName: 'file',
      bytes: bytes,
      fileName: fileName,
      extraFields: {'conversation_id': '$conversationId'},
    );
    final response = await http.Response.fromStream(streamed);
    _ensureOk(response, 'upload attachment');
    return _decodeMap(response);
  }

  // ── Presence ─────────────────────────────────────────────────────────────

  Future<void> heartbeat({String status = 'online'}) async {
    final r = await _api.post('/presence/heartbeat', body: {'status': status});
    _ensureOk(r, 'presence heartbeat');
  }

  Future<Map<int, PresenceStatus>> getPresence(List<int> userIds) async {
    if (userIds.isEmpty) return {};
    final r = await _api.get('/presence', queryParams: {'user_ids': userIds.join(',')});
    _ensureOk(r, 'get presence');
    final rows = _decodeList(r);
    final out = <int, PresenceStatus>{};
    for (final row in rows) {
      final uid = (row['user_id'] as num).toInt();
      final s = row['status']?.toString();
      out[uid] = s == 'online'
          ? PresenceStatus.online
          : s == 'away'
              ? PresenceStatus.away
              : PresenceStatus.offline;
    }
    return out;
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  void _ensureOk(http.Response r, String label) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    throw CommunityApiException(label: label, statusCode: r.statusCode, body: r.body);
  }

  Map<String, dynamic> _decodeMap(http.Response r) {
    if (r.body.isEmpty) return const {};
    final raw = jsonDecode(utf8.decode(r.bodyBytes));
    if (raw is! Map) throw CommunityApiException(label: 'decode', statusCode: r.statusCode, body: r.body);
    return Map<String, dynamic>.from(raw);
  }

  List<Map<String, dynamic>> _decodeList(http.Response r) {
    if (r.body.isEmpty) return const [];
    final raw = jsonDecode(utf8.decode(r.bodyBytes));
    if (raw is! List) throw CommunityApiException(label: 'decode-list', statusCode: r.statusCode, body: r.body);
    return raw.cast<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }
}

class CommunityApiException implements Exception {
  final String label;
  final int statusCode;
  final String body;

  CommunityApiException({required this.label, required this.statusCode, required this.body});

  @override
  String toString() => 'CommunityApiException($label, $statusCode): $body';
}
