import 'package:intl/intl.dart';

/// Age in whole years from an ISO birthday (website: calculateAge). Empty
/// when there's no usable date.
String calculateAge(String? birthday) {
  final date = DateTime.tryParse(birthday ?? '');
  if (date == null) return '';
  final today = DateTime.now();
  var age = today.year - date.year;
  if (today.month < date.month || (today.month == date.month && today.day < date.day)) age--;
  return '$age';
}

/// The intl locale for an app language code (bg / en / el / es) — every
/// one of them is initialised in main().
String intlLocale(String language) => switch (language) {
  'bg' || 'el' || 'es' => language,
  _ => 'en_US',
};

/// "12 октомври 2026 г., 14:05" / "October 12, 2026 at 14:05" — the
/// website's formatDateTime (long month, 24-hour clock).
String formatDateTime(String iso, String locale) {
  final date = DateTime.tryParse(iso)?.toLocal();
  if (date == null) return '';
  final languageTag = intlLocale(locale);
  return '${DateFormat.yMMMMd(languageTag).format(date)}, ${DateFormat.Hm(languageTag).format(date)}';
}

/// A cat-in-a-suit oil painting the website shows for actors without a
/// photo — same image, same CDN.
const fallbackActorImage =
    'https://res.cloudinary.com/dxkloyfs1/image/upload/v1760304531/funny-surreal-dog-oil-painting-funny-surreal-pet-animal-dog-classic-oil-painting-bulldog-upper-class-aristocrat-121874909_q0dxgq.webp';

/// A release / air date ("2026-10-09") in the app's language — "9 октомври
/// 2026 г.", "October 9, 2026", … (website: formatReleaseDate). A bare year or
/// anything unparseable comes back as-is.
String formatReleaseDate(String? value, String locale) {
  if (value == null || value.isEmpty) return '';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value.trim());
  if (match == null) return value;
  final date = DateTime.utc(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
  return DateFormat.yMMMMd(intlLocale(locale)).format(date);
}

/// A sortable value for a release date — missing / unparseable dates sort last.
int releaseDateValue(String? value) => DateTime.tryParse(value ?? '')?.millisecondsSinceEpoch ?? -8640000000000000;
