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
