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
}

class Quote {
  final String id;
  final String book;
  final String person;
  final String quote;
  final DateTime date;
  final String? createdBy;

  Quote({
    required this.id,
    required this.book,
    required this.person,
    required this.quote,
    required this.date,
    this.createdBy,
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
