// The parts of Clerk's Frontend API objects the app reads. Field names are
// Clerk's own (snake_case JSON).

String? _s(Object? value) => value?.toString();

class ClerkUser {
  const ClerkUser({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.imageUrl,
    this.hasImage = false,
    this.emails = const [],
    this.externalAccounts = const [],
    this.passwordEnabled = false,
    this.createdAt,
  });

  final String id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? imageUrl;
  final bool hasImage;

  /// For "Manage account".
  final List<ClerkEmail> emails;
  final List<ClerkExternalAccount> externalAccounts;
  final bool passwordEnabled;
  final DateTime? createdAt;

  String get fullName => [firstName, lastName].whereType<String>().where((part) => part.isNotEmpty).join(' ');

  /// What Clerk's UserButton shows first: the full name, else the email.
  String get displayName => fullName.isNotEmpty ? fullName : (email ?? '');

  factory ClerkUser.fromJson(Map<String, dynamic> json) {
    final primaryId = json['primary_email_address_id'];
    final emails = (json['email_addresses'] as List? ?? const []).whereType<Map<String, dynamic>>();
    final primary = emails.where((email) => email['id'] == primaryId).firstOrNull ?? emails.firstOrNull;
    return ClerkUser(
      id: '${json['id']}',
      firstName: _s(json['first_name']),
      lastName: _s(json['last_name']),
      email: _s(primary?['email_address']),
      imageUrl: _s(json['image_url']),
      hasImage: json['has_image'] == true,
      emails: [for (final email in emails) ClerkEmail.fromJson(email, isPrimary: email['id'] == primaryId)],
      externalAccounts: (json['external_accounts'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ClerkExternalAccount.fromJson)
          .toList(),
      passwordEnabled: json['password_enabled'] == true,
      createdAt: json['created_at'] is num ? DateTime.fromMillisecondsSinceEpoch((json['created_at'] as num).toInt()) : null,
    );
  }
}

class ClerkEmail {
  const ClerkEmail({required this.id, required this.address, required this.verified, required this.isPrimary});

  final String id;
  final String address;
  final bool verified;
  final bool isPrimary;

  factory ClerkEmail.fromJson(Map<String, dynamic> json, {required bool isPrimary}) => ClerkEmail(
    id: '${json['id']}',
    address: '${json['email_address'] ?? ''}',
    verified: (json['verification'] as Map?)?['status'] == 'verified',
    isPrimary: isPrimary,
  );
}

/// A sign-in method linked to the user (Google).
class ClerkExternalAccount {
  const ClerkExternalAccount({required this.id, required this.provider, this.email, this.verified = true});

  final String id;

  /// "google" (Clerk's provider is "oauth_google").
  final String provider;
  final String? email;
  final bool verified;

  factory ClerkExternalAccount.fromJson(Map<String, dynamic> json) => ClerkExternalAccount(
    id: '${json['id']}',
    provider: '${json['provider'] ?? ''}'.replaceFirst('oauth_', ''),
    email: _s(json['email_address']),
    verified: (json['verification'] as Map?)?['status'] != 'unverified',
  );
}

/// One signed-in device ("Active devices").
class ClerkDeviceSession {
  const ClerkDeviceSession({
    required this.id,
    this.isMobile = false,
    this.deviceType,
    this.browserName,
    this.browserVersion,
    this.ipAddress,
    this.city,
    this.country,
    this.lastActiveAt,
  });

  final String id;
  final bool isMobile;
  final String? deviceType;
  final String? browserName;
  final String? browserVersion;
  final String? ipAddress;
  final String? city;
  final String? country;
  final DateTime? lastActiveAt;

  factory ClerkDeviceSession.fromJson(Map<String, dynamic> json) {
    final activity = json['latest_activity'] as Map<String, dynamic>? ?? const {};
    return ClerkDeviceSession(
      id: '${json['id']}',
      isMobile: activity['is_mobile'] == true,
      deviceType: _s(activity['device_type']),
      browserName: _s(activity['browser_name']),
      browserVersion: _s(activity['browser_version']),
      ipAddress: _s(activity['ip_address']),
      city: _s(activity['city']),
      country: _s(activity['country']),
      lastActiveAt: json['last_active_at'] is num ? DateTime.fromMillisecondsSinceEpoch((json['last_active_at'] as num).toInt()) : null,
    );
  }
}

class ClerkSession {
  const ClerkSession({required this.id, required this.status, required this.user});

  final String id;
  final String status;
  final ClerkUser user;

  factory ClerkSession.fromJson(Map<String, dynamic> json) =>
      ClerkSession(id: '${json['id']}', status: '${json['status']}', user: ClerkUser.fromJson(json['user'] as Map<String, dynamic>));
}

/// One way to prove who you are on a sign-in (`password`, `email_code`,
/// `reset_password_email_code`…).
class ClerkFactor {
  const ClerkFactor({required this.strategy, this.emailAddressId, this.safeIdentifier});

  final String strategy;
  final String? emailAddressId;
  final String? safeIdentifier;

  factory ClerkFactor.fromJson(Map<String, dynamic> json) => ClerkFactor(
    strategy: '${json['strategy']}',
    emailAddressId: _s(json['email_address_id']),
    safeIdentifier: _s(json['safe_identifier']),
  );
}

List<ClerkFactor> _factors(Object? value) =>
    (value as List? ?? const []).whereType<Map<String, dynamic>>().map(ClerkFactor.fromJson).toList();

class ClerkVerification {
  const ClerkVerification({this.status, this.strategy, this.externalRedirectUrl});

  final String? status;
  final String? strategy;
  final String? externalRedirectUrl;

  factory ClerkVerification.fromJson(Map<String, dynamic>? json) => ClerkVerification(
    status: _s(json?['status']),
    strategy: _s(json?['strategy']),
    externalRedirectUrl: _s(json?['external_verification_redirect_url']),
  );
}

/// A sign-in in progress. [status]: `needs_identifier`, `needs_first_factor`,
/// `needs_second_factor`, `needs_new_password`, `complete`, …
class ClerkSignIn {
  const ClerkSignIn({
    required this.id,
    required this.status,
    this.identifier,
    this.firstFactors = const [],
    this.secondFactors = const [],
    this.firstFactorVerification = const ClerkVerification(),
    this.createdSessionId,
  });

  final String id;
  final String status;
  final String? identifier;
  final List<ClerkFactor> firstFactors;
  final List<ClerkFactor> secondFactors;
  final ClerkVerification firstFactorVerification;
  final String? createdSessionId;

  ClerkFactor? firstFactor(String strategy) => firstFactors.where((factor) => factor.strategy == strategy).firstOrNull;
  ClerkFactor? secondFactor(String strategy) => secondFactors.where((factor) => factor.strategy == strategy).firstOrNull;

  factory ClerkSignIn.fromJson(Map<String, dynamic> json) => ClerkSignIn(
    id: '${json['id']}',
    status: '${json['status']}',
    identifier: _s(json['identifier']),
    firstFactors: _factors(json['supported_first_factors']),
    secondFactors: _factors(json['supported_second_factors']),
    firstFactorVerification: ClerkVerification.fromJson(json['first_factor_verification'] as Map<String, dynamic>?),
    createdSessionId: _s(json['created_session_id']),
  );
}

/// A sign-up in progress. [status]: `missing_requirements` or `complete`.
class ClerkSignUp {
  const ClerkSignUp({
    required this.id,
    required this.status,
    this.emailAddress,
    this.unverifiedFields = const [],
    this.missingFields = const [],
    this.createdSessionId,
  });

  final String id;
  final String status;
  final String? emailAddress;
  final List<String> unverifiedFields;
  final List<String> missingFields;
  final String? createdSessionId;

  factory ClerkSignUp.fromJson(Map<String, dynamic> json) => ClerkSignUp(
    id: '${json['id']}',
    status: '${json['status']}',
    emailAddress: _s(json['email_address']),
    unverifiedFields: (json['unverified_fields'] as List? ?? const []).map((field) => '$field').toList(),
    missingFields: (json['missing_fields'] as List? ?? const []).map((field) => '$field').toList(),
    createdSessionId: _s(json['created_session_id']),
  );
}
