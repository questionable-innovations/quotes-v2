/// Data models mirroring the quotes-v2 backend DTOs.

class User {
  final String id;
  final String email;
  final bool emailVerified;

  User({required this.id, required this.email, required this.emailVerified});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        emailVerified: json['email_verified'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'email_verified': emailVerified,
      };
}

class Book {
  final String id;
  final String name;
  final String ownerId;
  final String ownerEmail;
  final bool isOwner;
  final int quoteCount;

  Book({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.ownerEmail,
    required this.isOwner,
    required this.quoteCount,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled',
        ownerId: json['owner']['id'] as String,
        ownerEmail: json['owner']['email'] as String,
        isOwner: json['is_owner'] as bool? ?? false,
        quoteCount: (json['quote_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': {'id': ownerId, 'email': ownerEmail},
        'is_owner': isOwner,
        'quote_count': quoteCount,
      };
}

class Attachment {
  final String id;
  final String filename;
  final String contentType;
  final int sizeBytes;

  Attachment({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
  });

  bool get isImage => contentType.startsWith('image/');

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json['id'] as String,
        filename: json['filename'] as String? ?? 'attachment',
        contentType:
            json['content_type'] as String? ?? 'application/octet-stream',
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'content_type': contentType,
        'size_bytes': sizeBytes,
      };
}

class Quote {
  final String id;
  final String book;
  final String person;
  final String quote;
  final DateTime date;
  final String? createdBy;
  final List<Attachment> attachments;

  Quote({
    required this.id,
    required this.book,
    required this.person,
    required this.quote,
    required this.date,
    this.createdBy,
    this.attachments = const [],
  });

  factory Quote.fromJson(Map<String, dynamic> json, {required String bookId}) =>
      Quote(
        id: json['id'] as String,
        book: bookId,
        person: json['person'] as String,
        quote: json['quote'] as String,
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        createdBy: json['created_by'] as String?,
        attachments: (json['attachments'] as List<dynamic>? ?? [])
            .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'person': person,
        'quote': quote,
        'date': date.toIso8601String(),
        'created_by': createdBy,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  Quote withAttachments(List<Attachment> attachments) => Quote(
        id: id,
        book: book,
        person: person,
        quote: quote,
        date: date,
        createdBy: createdBy,
        attachments: attachments,
      );
}

class Member {
  final String id;
  final String email;

  Member({required this.id, required this.email});

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        email: json['email'] as String,
      );
}

class Invite {
  final String id;
  final String email;
  final DateTime? expiresAt;

  Invite({required this.id, required this.email, this.expiresAt});

  factory Invite.fromJson(Map<String, dynamic> json) => Invite(
        id: json['id'] as String,
        email: json['email'] as String,
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      );
}

class ShareLink {
  final String id;
  final String url;
  final DateTime? expiresAt;
  final int? maxUses;
  final int uses;
  final bool revoked;

  ShareLink({
    required this.id,
    required this.url,
    this.expiresAt,
    this.maxUses,
    required this.uses,
    required this.revoked,
  });

  factory ShareLink.fromJson(Map<String, dynamic> json) => ShareLink(
        id: json['id'] as String,
        url: json['url'] as String? ?? '',
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
        maxUses: (json['max_uses'] as num?)?.toInt(),
        uses: (json['uses'] as num?)?.toInt() ?? 0,
        revoked: json['revoked'] as bool? ?? false,
      );
}

/// Public preview of a share link's target book.
class SharePreview {
  final String? bookName;
  final String ownerEmail;

  SharePreview({this.bookName, required this.ownerEmail});

  factory SharePreview.fromJson(Map<String, dynamic> json) => SharePreview(
        bookName: json['book_name'] as String?,
        ownerEmail: json['owner_email'] as String? ?? '',
      );
}

/// Result of adding a member: either added directly or an email invite was sent.
class AddMemberResult {
  final bool added;
  final bool invited;

  AddMemberResult({required this.added, required this.invited});

  factory AddMemberResult.fromJson(Map<String, dynamic> json) =>
      AddMemberResult(
        added: json['added'] as bool? ?? false,
        invited: json['invited'] as bool? ?? false,
      );
}
