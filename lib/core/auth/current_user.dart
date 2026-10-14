import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'auth_controller.dart';

enum SubscriptionType { regular, pro }

/// The signed-in person as lumo-user-svc knows them (gateway `GET /user/me`)
/// — the website's useCurrentUser(). Mainly for the subscription plan.
class CurrentUser {
  const CurrentUser({required this.clerkId, required this.subscription, this.displayName, this.profileImageURL});

  final String clerkId;
  final SubscriptionType subscription;
  final String? displayName;
  final String? profileImageURL;

  bool get isPro => subscription == SubscriptionType.pro;
}

/// Null while signed out — and briefly right after sign-up, until Clerk's
/// webhook has created the user in the database.
final currentUserProvider = FutureProvider<CurrentUser?>((ref) async {
  final signedInAs = ref.watch(authProvider.select((auth) => auth.user?.id));
  if (signedInAs == null) return null;

  final data = await ref.read(apiClientProvider).getJson('/user/me');
  if (data is! Map<String, dynamic>) return null;
  return CurrentUser(
    clerkId: '${data['clerkId']}',
    subscription: data['subscriptionType'] == 'PRO_USER' ? SubscriptionType.pro : SubscriptionType.regular,
    displayName: data['displayName'] as String?,
    profileImageURL: data['profileImageURL'] as String?,
  );
});
