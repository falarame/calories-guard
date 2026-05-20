// Data models for the community / chat / referral feature.
// Kept as plain immutable Dart classes (no codegen) to match the rest of
// the codebase. JSON parsing is intentionally permissive — backend
// already validates shapes, so we focus on null-safety here.

class CommunityUser {
  final int userId;
  final String username;
  final String? avatarUrl;

  const CommunityUser({required this.userId, required this.username, this.avatarUrl});

  factory CommunityUser.fromJson(Map<String, dynamic> j) => CommunityUser(
        userId: (j['user_id'] as num).toInt(),
        username: j['username']?.toString() ?? '',
        avatarUrl: j['avatar_url']?.toString(),
      );
}

enum PresenceStatus { online, away, offline }

PresenceStatus _presenceFromString(String? s) {
  switch (s) {
    case 'online':
      return PresenceStatus.online;
    case 'away':
      return PresenceStatus.away;
    default:
      return PresenceStatus.offline;
  }
}

class FriendEntry {
  final int userId;
  final String username;
  final String? avatarUrl;
  final PresenceStatus presence;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  const FriendEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.presence = PresenceStatus.offline,
    this.lastSeenAt,
    this.createdAt,
  });

  factory FriendEntry.fromJson(Map<String, dynamic> j) => FriendEntry(
        userId: (j['user_id'] as num).toInt(),
        username: j['username']?.toString() ?? '',
        avatarUrl: j['avatar_url']?.toString(),
        presence: _presenceFromString(j['presence']?.toString()),
        lastSeenAt: _ts(j['last_seen_at']),
        createdAt: _ts(j['created_at']),
      );
}

class ConversationSummary {
  final int conversationId;
  final String type; // 'dm' or 'group'
  final String? name;
  final String? avatarUrl;
  final DateTime? lastMessageAt;
  final int? lastMessageId;
  final String? lastMessageBody;
  final String? lastMessageKind;
  final int? lastMessageSender;
  final int unreadCount;
  final bool muted;
  final bool archived;
  final int? lastReadMessageId;

  // DM-only convenience fields (peer user)
  final int? peerUserId;
  final String? peerUsername;
  final String? peerAvatar;

  const ConversationSummary({
    required this.conversationId,
    required this.type,
    this.name,
    this.avatarUrl,
    this.lastMessageAt,
    this.lastMessageId,
    this.lastMessageBody,
    this.lastMessageKind,
    this.lastMessageSender,
    this.unreadCount = 0,
    this.muted = false,
    this.archived = false,
    this.lastReadMessageId,
    this.peerUserId,
    this.peerUsername,
    this.peerAvatar,
  });

  String get displayTitle =>
      type == 'dm' ? (peerUsername ?? 'แชท') : (name ?? 'กลุ่ม');

  String? get displayAvatar => type == 'dm' ? peerAvatar : avatarUrl;

  factory ConversationSummary.fromJson(Map<String, dynamic> j) => ConversationSummary(
        conversationId: (j['conversation_id'] as num).toInt(),
        type: j['type']?.toString() ?? 'dm',
        name: j['name']?.toString(),
        avatarUrl: j['avatar_url']?.toString(),
        lastMessageAt: _ts(j['last_message_at']),
        lastMessageId: (j['last_message_id'] as num?)?.toInt(),
        lastMessageBody: j['last_message_body']?.toString(),
        lastMessageKind: j['last_message_kind']?.toString(),
        lastMessageSender: (j['last_message_sender'] as num?)?.toInt(),
        unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
        muted: j['muted'] == true,
        archived: j['archived'] == true,
        lastReadMessageId: (j['last_read_message_id'] as num?)?.toInt(),
        peerUserId: (j['peer_user_id'] as num?)?.toInt(),
        peerUsername: j['peer_username']?.toString(),
        peerAvatar: j['peer_avatar']?.toString(),
      );

  ConversationSummary copyWith({int? unreadCount, DateTime? lastMessageAt, int? lastMessageId, String? lastMessageBody, String? lastMessageKind, int? lastMessageSender}) =>
      ConversationSummary(
        conversationId: conversationId,
        type: type,
        name: name,
        avatarUrl: avatarUrl,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        lastMessageId: lastMessageId ?? this.lastMessageId,
        lastMessageBody: lastMessageBody ?? this.lastMessageBody,
        lastMessageKind: lastMessageKind ?? this.lastMessageKind,
        lastMessageSender: lastMessageSender ?? this.lastMessageSender,
        unreadCount: unreadCount ?? this.unreadCount,
        muted: muted,
        archived: archived,
        lastReadMessageId: lastReadMessageId,
        peerUserId: peerUserId,
        peerUsername: peerUsername,
        peerAvatar: peerAvatar,
      );
}

class ChatMessage {
  final int messageId;
  final int conversationId;
  final int? senderUserId;
  final String kind; // text | image | file | system
  final String? body;
  final String? attachmentUrl;
  final String? attachmentMime;
  final int? attachmentSize;
  final String? attachmentName;
  final int? replyToMessageId;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;

  const ChatMessage({
    required this.messageId,
    required this.conversationId,
    this.senderUserId,
    required this.kind,
    this.body,
    this.attachmentUrl,
    this.attachmentMime,
    this.attachmentSize,
    this.attachmentName,
    this.replyToMessageId,
    this.editedAt,
    this.deletedAt,
    required this.createdAt,
  });

  bool get isDeleted => deletedAt != null;
  bool get isSystem => kind == 'system';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        messageId: (j['message_id'] as num).toInt(),
        conversationId: (j['conversation_id'] as num).toInt(),
        senderUserId: (j['sender_user_id'] as num?)?.toInt(),
        kind: j['kind']?.toString() ?? 'text',
        body: j['body']?.toString(),
        attachmentUrl: j['attachment_url']?.toString(),
        attachmentMime: j['attachment_mime']?.toString(),
        attachmentSize: (j['attachment_size'] as num?)?.toInt(),
        attachmentName: j['attachment_name']?.toString(),
        replyToMessageId: (j['reply_to_message_id'] as num?)?.toInt(),
        editedAt: _ts(j['edited_at']),
        deletedAt: _ts(j['deleted_at']),
        createdAt: _ts(j['created_at']) ?? DateTime.now(),
      );
}

class ReferralSummary {
  final String code;
  final String shareUrl;
  final String deepLink;
  final int totalInvites;
  final int acceptedCount;
  final int rewardedCount;
  final int totalGemsEarned;
  final int totalXpEarned;

  const ReferralSummary({
    required this.code,
    required this.shareUrl,
    required this.deepLink,
    required this.totalInvites,
    required this.acceptedCount,
    required this.rewardedCount,
    required this.totalGemsEarned,
    required this.totalXpEarned,
  });

  factory ReferralSummary.fromJson(Map<String, dynamic> j) => ReferralSummary(
        code: j['code']?.toString() ?? '',
        shareUrl: j['share_url']?.toString() ?? '',
        deepLink: j['deep_link']?.toString() ?? '',
        totalInvites: (j['total_invites'] as num?)?.toInt() ?? 0,
        acceptedCount: (j['accepted_count'] as num?)?.toInt() ?? 0,
        rewardedCount: (j['rewarded_count'] as num?)?.toInt() ?? 0,
        totalGemsEarned: (j['total_gems_earned'] as num?)?.toInt() ?? 0,
        totalXpEarned: (j['total_xp_earned'] as num?)?.toInt() ?? 0,
      );
}

class InviteePreview {
  final int referralId;
  final int inviteeUserId;
  final String inviteeUsername;
  final String? inviteeAvatar;
  final String source;
  final String status;
  final DateTime? rewardGrantedAt;
  final DateTime? createdAt;

  const InviteePreview({
    required this.referralId,
    required this.inviteeUserId,
    required this.inviteeUsername,
    this.inviteeAvatar,
    required this.source,
    required this.status,
    this.rewardGrantedAt,
    this.createdAt,
  });

  factory InviteePreview.fromJson(Map<String, dynamic> j) => InviteePreview(
        referralId: (j['referral_id'] as num).toInt(),
        inviteeUserId: (j['invitee_user_id'] as num).toInt(),
        inviteeUsername: j['invitee_username']?.toString() ?? '',
        inviteeAvatar: j['invitee_avatar']?.toString(),
        source: j['source']?.toString() ?? 'link',
        status: j['status']?.toString() ?? 'pending',
        rewardGrantedAt: _ts(j['reward_granted_at']),
        createdAt: _ts(j['created_at']),
      );
}

class ReferralPreview {
  final bool valid;
  final String kind; // 'link' or 'email'
  final String inviterUsername;
  final String? inviterAvatar;

  const ReferralPreview({
    required this.valid,
    required this.kind,
    required this.inviterUsername,
    this.inviterAvatar,
  });

  factory ReferralPreview.fromJson(Map<String, dynamic> j) => ReferralPreview(
        valid: j['valid'] == true,
        kind: j['kind']?.toString() ?? 'link',
        inviterUsername: j['inviter_username']?.toString() ?? '',
        inviterAvatar: j['inviter_avatar']?.toString(),
      );
}

DateTime? _ts(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}
