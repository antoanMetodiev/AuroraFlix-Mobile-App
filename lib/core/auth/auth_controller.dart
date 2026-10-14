import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'clerk_api.dart';
import 'clerk_models.dart';

enum AuthStatus { loading, signedOut, signedIn }

class AuthState {
  const AuthState._(this.status, [this.session]);

  const AuthState.loading() : this._(AuthStatus.loading);
  const AuthState.signedOut() : this._(AuthStatus.signedOut);
  const AuthState.signedIn(ClerkSession session) : this._(AuthStatus.signedIn, session);

  final AuthStatus status;
  final ClerkSession? session;

  bool get isLoaded => status != AuthStatus.loading;
  bool get isSignedIn => status == AuthStatus.signedIn;
  ClerkUser? get user => session?.user;
}

final clerkApiProvider = Provider<ClerkApi>((ref) => ClerkApi());

/// The app's Clerk session — the website's `useUser()` / `useAuth()`.
/// Restores the stored client on start, exposes the signed-in user, hands
/// out session tokens for the gateway, and runs the steps of the sign-in /
/// sign-up flows (the modal screens drive these).
class AuthController extends Notifier<AuthState> {
  ClerkApi get _api => ref.read(clerkApiProvider);

  String? _cachedToken;
  DateTime? _cachedTokenExpiry;

  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthState.loading();
  }

  Future<void> _restore() async {
    if (!await _api.hasStoredClient()) {
      state = const AuthState.signedOut();
      return;
    }
    try {
      _applyClient(await _api.request('GET', '/client'));
    } on ClerkException {
      state = const AuthState.signedOut();
    }
  }

  /// Every Frontend API response carries the whole client (`client` next to
  /// `response`, or as the `response` itself for /client calls) — the source
  /// of truth for who is signed in.
  void _applyClient(Map<String, dynamic> body) {
    final client =
        (body['client'] ?? (body['response'] is Map && (body['response'] as Map)['object'] == 'client' ? body['response'] : null))
            as Map<String, dynamic>?;
    if (client == null) {
      if (body.containsKey('client') || body['response'] == null) state = const AuthState.signedOut();
      return;
    }

    final sessions = (client['sessions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ClerkSession.fromJson)
        .where((session) => session.status == 'active')
        .toList();
    final activeId = client['last_active_session_id'];
    final active = sessions.where((session) => session.id == activeId).firstOrNull ?? sessions.firstOrNull;

    if (active?.id != state.session?.id) {
      _cachedToken = null;
      _cachedTokenExpiry = null;
    }
    state = active == null ? const AuthState.signedOut() : AuthState.signedIn(active);
  }

  Future<void> _ensureClient() async {
    if (!await _api.hasStoredClient()) _applyClient(await _api.request('POST', '/client'));
  }

  Future<Map<String, dynamic>> _call(String method, String path, {Map<String, String>? form}) async {
    await _ensureClient();
    try {
      final body = await _api.request(method, path, form: form);
      _applyClient(body);
      return body;
    } on ClerkException catch (error) {
      // The stored client is gone (expired / signed out elsewhere) — start a
      // fresh one and retry once.
      if (error.code == 'client_not_found' || error.code == 'authentication_invalid') {
        await _api.forgetClient();
        await _ensureClient();
        final body = await _api.request(method, path, form: form);
        _applyClient(body);
        return body;
      }
      rethrow;
    }
  }

  // --- Session tokens --------------------------------------------------------

  /// A short-lived session JWT for `Authorization: Bearer` on gateway calls —
  /// the website's `getToken()`. Cached until shortly before it expires.
  Future<String?> getToken() async {
    final session = state.session;
    if (session == null) return null;
    final expiry = _cachedTokenExpiry;
    if (_cachedToken != null && expiry != null && DateTime.now().isBefore(expiry)) return _cachedToken;

    try {
      final body = await _api.request('POST', '/client/sessions/${session.id}/tokens');
      final jwt = (body['jwt'] ?? (body['response'] as Map?)?['jwt'])?.toString();
      if (jwt == null) return null;
      _cachedToken = jwt;
      _cachedTokenExpiry = _jwtExpiry(jwt)?.subtract(const Duration(seconds: 10));
      return jwt;
    } on ClerkException {
      return null;
    }
  }

  static DateTime? _jwtExpiry(String jwt) {
    try {
      final payload = jwt.split('.')[1];
      final json = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload)))) as Map<String, dynamic>;
      return DateTime.fromMillisecondsSinceEpoch((json['exp'] as num).toInt() * 1000);
    } catch (_) {
      return null;
    }
  }

  // --- Sign in -----------------------------------------------------------------

  /// Step 1: the email address. Returns the sign-in, which then needs a
  /// first factor (password, or an email code).
  Future<ClerkSignIn> startSignIn(String identifier) async {
    final body = await _call('POST', '/client/sign_ins', form: {'identifier': identifier});
    return ClerkSignIn.fromJson(body['response'] as Map<String, dynamic>);
  }

  Future<ClerkSignIn> attemptPassword(String signInId, String password) =>
      _signInStep('/client/sign_ins/$signInId/attempt_first_factor', {'strategy': 'password', 'password': password});

  /// Emails a one-time code — `email_code` to sign in, or
  /// `reset_password_email_code` for "Forgot password?".
  Future<ClerkSignIn> prepareFirstFactor(String signInId, ClerkFactor factor) => _signInStep(
    '/client/sign_ins/$signInId/prepare_first_factor',
    {'strategy': factor.strategy, if (factor.emailAddressId != null) 'email_address_id': factor.emailAddressId!},
  );

  Future<ClerkSignIn> attemptFirstFactorCode(String signInId, String strategy, String code) =>
      _signInStep('/client/sign_ins/$signInId/attempt_first_factor', {'strategy': strategy, 'code': code});

  /// New-device / two-step verification by emailed code.
  Future<ClerkSignIn> prepareSecondFactor(String signInId, ClerkFactor factor) => _signInStep(
    '/client/sign_ins/$signInId/prepare_second_factor',
    {'strategy': factor.strategy, if (factor.emailAddressId != null) 'email_address_id': factor.emailAddressId!},
  );

  Future<ClerkSignIn> attemptSecondFactorCode(String signInId, String strategy, String code) =>
      _signInStep('/client/sign_ins/$signInId/attempt_second_factor', {'strategy': strategy, 'code': code});

  Future<ClerkSignIn> resetPassword(String signInId, String password, {required bool signOutOfOtherSessions}) => _signInStep(
    '/client/sign_ins/$signInId/reset_password',
    {'password': password, 'sign_out_of_other_sessions': '$signOutOfOtherSessions'},
  );

  Future<ClerkSignIn> _signInStep(String path, Map<String, String> form) async {
    final body = await _call('POST', path, form: form);
    final signIn = ClerkSignIn.fromJson(body['response'] as Map<String, dynamic>);
    if (signIn.status == 'complete' && signIn.createdSessionId != null) await _activate(signIn.createdSessionId!);
    return signIn;
  }

  // --- Sign up -----------------------------------------------------------------

  Future<ClerkSignUp> startSignUp({required String email, required String password, String? firstName, String? lastName}) async {
    final body = await _call(
      'POST',
      '/client/sign_ups',
      form: {
        'email_address': email,
        'password': password,
        if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
        if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
      },
    );
    return ClerkSignUp.fromJson(body['response'] as Map<String, dynamic>);
  }

  Future<ClerkSignUp> prepareEmailVerification(String signUpId) async {
    final body = await _call('POST', '/client/sign_ups/$signUpId/prepare_verification', form: {'strategy': 'email_code'});
    return ClerkSignUp.fromJson(body['response'] as Map<String, dynamic>);
  }

  Future<ClerkSignUp> attemptEmailVerification(String signUpId, String code) async {
    final body = await _call('POST', '/client/sign_ups/$signUpId/attempt_verification', form: {'strategy': 'email_code', 'code': code});
    final signUp = ClerkSignUp.fromJson(body['response'] as Map<String, dynamic>);
    if (signUp.status == 'complete' && signUp.createdSessionId != null) await _activate(signUp.createdSessionId!);
    return signUp;
  }

  // --- Google ------------------------------------------------------------------

  /// "Continue with Google": Clerk hands back Google's consent URL, the
  /// browser runs it, and Clerk redirects to [_oauthRedirectUrl] with a
  /// one-time `rotating_token_nonce` that swaps the browser's result into
  /// this client. A Google account with no AuroraFlix user yet comes back
  /// "transferable" and is turned into a sign-up — same as the website.
  ///
  /// Returns false if the person closed the browser without finishing.
  Future<bool> signInWithGoogle() async {
    final body = await _call('POST', '/client/sign_ins', form: {'strategy': 'oauth_google', 'redirect_url': _oauthRedirectUrl});
    final started = ClerkSignIn.fromJson(body['response'] as Map<String, dynamic>);
    final consentUrl = started.firstFactorVerification.externalRedirectUrl;
    if (consentUrl == null) throw ClerkException.network();

    final String callback;
    try {
      callback = await FlutterWebAuth2.authenticate(url: consentUrl, callbackUrlScheme: _oauthScheme);
    } on PlatformException {
      return false;
    }

    // The nonce has to be redeemed on the sign-in itself (what Clerk's own
    // native SDKs do): that's what moves the finished sign-in onto this
    // client. `GET /client` silently ignores it — the phone came back from
    // Google still signed out.
    final nonce = Uri.parse(callback).queryParameters['rotating_token_nonce'];
    final Map<String, dynamic> signInJson;
    if (nonce != null) {
      final reloaded = await _api.request('GET', '/client/sign_ins/${started.id}', query: {'rotating_token_nonce': nonce});
      _applyClient(reloaded);
      if (state.isSignedIn) return true;
      signInJson = reloaded['response'] as Map<String, dynamic>? ?? const {};
    } else {
      final client = await _api.request('GET', '/client');
      _applyClient(client);
      if (state.isSignedIn) return true;
      signInJson = ((client['response'] as Map<String, dynamic>?)?['sign_in']) as Map<String, dynamic>? ?? const {};
    }
    final signIn = signInJson.isEmpty ? null : ClerkSignIn.fromJson(signInJson);
    if (signIn?.status == 'complete' && signIn?.createdSessionId != null) {
      await _activate(signIn!.createdSessionId!);
      return true;
    }
    if (signIn?.firstFactorVerification.status == 'transferable') {
      final transfer = await _call('POST', '/client/sign_ups', form: {'transfer': 'true'});
      final signUp = ClerkSignUp.fromJson(transfer['response'] as Map<String, dynamic>);
      if (signUp.createdSessionId != null) await _activate(signUp.createdSessionId!);
      return state.isSignedIn;
    }
    return state.isSignedIn;
  }

  static const _oauthScheme = 'cloud.auroraflix';

  /// Where Clerk sends the browser back after Google — must be on the Clerk
  /// instance's allowlist (Dashboard → Native applications). The browser
  /// build uses web/auth.html on the dev server instead of the app scheme.
  static String get _oauthRedirectUrl => kIsWeb ? '${Uri.base.origin}/auth.html' : '$_oauthScheme://sso-callback';

  // --- Manage account (Clerk's UserProfile) ---------------------------------

  /// A call on the signed-in user (`/me…`). Every response carries the whole
  /// client, so the user shown everywhere updates right away.
  Future<Map<String, dynamic>> _me(String method, String path, {Map<String, String>? form, http.MultipartFile? file}) async {
    final session = state.session;
    if (session == null) throw const ClerkException(code: 'signed_out', message: 'You are signed out.');
    final body = await _api.request(method, '/me$path', form: form, file: file, query: {'_clerk_session_id': session.id});
    _applyClient(body);
    return body;
  }

  /// The user as it is on Clerk right now.
  Future<void> reloadUser() async => _applyClient(await _api.request('GET', '/client'));

  Future<void> updateName(String firstName, String lastName) =>
      _me('PATCH', '', form: {'first_name': firstName, 'last_name': lastName});

  Future<void> uploadProfileImage(List<int> bytes, String filename) =>
      _me('POST', '/profile_image', file: http.MultipartFile.fromBytes('file', bytes, filename: filename));

  Future<void> removeProfileImage() async {
    await _me('DELETE', '/profile_image');
    await reloadUser();
  }

  /// Adds an address and emails it a code; returns the new address's id.
  Future<String> addEmail(String address) async {
    final body = await _me('POST', '/email_addresses', form: {'email_address': address});
    final id = '${(body['response'] as Map?)?['id']}';
    await _me('POST', '/email_addresses/$id/prepare_verification', form: {'strategy': 'email_code'});
    return id;
  }

  Future<void> resendEmailCode(String emailId) =>
      _me('POST', '/email_addresses/$emailId/prepare_verification', form: {'strategy': 'email_code'});

  Future<void> verifyEmail(String emailId, String code) async {
    await _me('POST', '/email_addresses/$emailId/attempt_verification', form: {'code': code});
    await reloadUser();
  }

  Future<void> removeEmail(String emailId) async {
    await _me('DELETE', '/email_addresses/$emailId');
    await reloadUser();
  }

  Future<void> setPrimaryEmail(String emailId) => _me('PATCH', '', form: {'primary_email_address_id': emailId});

  /// "Connect account" → Google: same browser round trip as signing in.
  Future<void> connectGoogle() async {
    final body = await _me('POST', '/external_accounts', form: {'strategy': 'oauth_google', 'redirect_url': _oauthRedirectUrl});
    final response = body['response'] as Map<String, dynamic>? ?? const {};
    final url = ClerkVerification.fromJson(response['verification'] as Map<String, dynamic>?).externalRedirectUrl;
    if (url == null) throw ClerkException.network();
    try {
      await FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: _oauthScheme);
    } on PlatformException {
      return;
    }
    await reloadUser();
  }

  Future<void> removeExternalAccount(String id) async {
    await _me('DELETE', '/external_accounts/$id');
    await reloadUser();
  }

  /// Sets or changes the password ([current] is null when there's none yet).
  Future<void> updatePassword({String? current, required String next, required bool signOutOthers}) => _me(
    'POST',
    '/change_password',
    form: {'current_password': ?current, 'new_password': next, 'sign_out_of_other_sessions': '$signOutOthers'},
  );

  /// "Active devices".
  Future<List<ClerkDeviceSession>> activeDevices() async {
    final session = state.session;
    if (session == null) return const [];
    final body = await _api.request('GET', '/me/sessions/active', query: {'_clerk_session_id': session.id});
    final list = body['response'] is List ? body['response'] as List : const [];
    return list.whereType<Map<String, dynamic>>().map(ClerkDeviceSession.fromJson).toList();
  }

  Future<void> signOutDevice(String sessionId) => _me('POST', '/sessions/$sessionId/revoke');

  /// "Delete account" — the user and everything Clerk holds for them.
  Future<void> deleteAccount() async {
    await _me('DELETE', '');
    state = const AuthState.signedOut();
    _cachedToken = null;
    _cachedTokenExpiry = null;
  }

  // --- Session ---------------------------------------------------------------

  Future<void> _activate(String sessionId) async {
    _applyClient(await _api.request('POST', '/client/sessions/$sessionId/touch'));
  }

  Future<void> signOut() async {
    final session = state.session;
    state = const AuthState.signedOut();
    _cachedToken = null;
    _cachedTokenExpiry = null;
    if (session == null) return;
    try {
      await _api.request('POST', '/client/sessions/${session.id}/end');
    } on ClerkException {
      // Already gone server-side — signed out either way.
    }
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
