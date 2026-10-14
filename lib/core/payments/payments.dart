import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';

/// The person's plan as lumo-payments-svc sees it (website: useSubscription).
class SubscriptionInfo {
  const SubscriptionInfo({required this.isPro, required this.status, this.currentPeriodEnd, this.cancelAtPeriodEnd = false});

  final bool isPro;
  final String status;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) => SubscriptionInfo(
    isPro: json['plan'] == 'PRO',
    status: '${json['status'] ?? 'NONE'}',
    currentPeriodEnd: DateTime.tryParse('${json['currentPeriodEnd'] ?? ''}')?.toLocal(),
    cancelAtPeriodEnd: json['cancelAtPeriodEnd'] == true,
  );
}

/// Stripe through the gateway (website: /api/payments/*). Checkout and the
/// billing portal open in the browser; coming back to the app refreshes the
/// plan (see AppShell).
class PaymentsApi {
  PaymentsApi(this._api);

  final ApiClient _api;

  Future<SubscriptionInfo?> subscription() async {
    final data = await _api.getJson('/payments/subscription');
    return data is Map<String, dynamic> ? SubscriptionInfo.fromJson(data) : null;
  }

  Future<String?> _sessionUrl(String path, {Object? body}) async {
    final response = await _api.send('POST', path, body: body);
    if (response == null || response.statusCode >= 300) return null;
    final data = ApiClient.decode(response);
    return data is Map && data['url'] is String ? data['url'] as String : null;
  }

  /// Opens Stripe Checkout for Pro. False if it couldn't be started.
  Future<bool> startCheckout(String email) async {
    final url = await _sessionUrl('/payments/checkout-session', body: {'email': email});
    return url != null && await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Opens Stripe's billing portal (change card, cancel…).
  Future<bool> openPortal() async {
    final url = await _sessionUrl('/payments/portal-session');
    return url != null && await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

final paymentsApiProvider = Provider<PaymentsApi>((ref) => PaymentsApi(ref.watch(apiClientProvider)));

/// Null while signed out (or if the service didn't answer).
final subscriptionProvider = FutureProvider<SubscriptionInfo?>((ref) async {
  final signedInAs = ref.watch(authProvider.select((auth) => auth.user?.id));
  if (signedInAs == null) return null;
  return ref.read(paymentsApiProvider).subscription();
});

enum CheckoutState { idle, redirecting, error }

/// The Pricing section's "Go Pro": idle → redirecting (while the Stripe
/// session is created and the browser opens) → idle again, or error.
class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => CheckoutState.idle;

  Future<void> start() async {
    final email = ref.read(authProvider).user?.email;
    if (email == null || state == CheckoutState.redirecting) return;
    state = CheckoutState.redirecting;
    final ok = await ref.read(paymentsApiProvider).startCheckout(email);
    state = ok ? CheckoutState.idle : CheckoutState.error;
  }
}

final checkoutProvider = NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);
