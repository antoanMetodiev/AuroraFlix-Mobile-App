import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n/locale.dart';
import '../core/theme.dart';

const _linkedInUrl = 'https://www.linkedin.com/in/antoan-metodiev-875518303';

const _columns = [
  ('footer.browse', ['footer.movies', 'footer.series', 'footer.genres', 'footer.newReleases']),
  ('footer.company', ['footer.about', 'footer.careers', 'footer.press', 'footer.partners']),
  ('footer.community', ['footer.blog', 'footer.support', 'footer.watchlist', 'footer.orderTitle']),
  ('footer.legal', ['footer.privacy', 'footer.terms', 'footer.cookies', 'footer.contact']),
];

const _socialIcons = [FontAwesomeIcons.facebook, FontAwesomeIcons.instagram, FontAwesomeIcons.twitter, FontAwesomeIcons.youtube];

/// The website's Footer, phone layout: brand block, then the four link
/// columns in a 2×2 grid.
class SiteFooter extends ConsumerWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final muted = AppColors.fg(0.5);

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AURORAFLIX',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 1.8, color: AppColors.fg(0.85)),
          ),
          const SizedBox(height: 16),
          Text(
            '© ${DateTime.now().year} AuroraFlix. ${t('footer.rights')}',
            style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.fg(0.7)),
          ),
          const SizedBox(height: 16),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${t('footer.tagline')} ', style: TextStyle(fontSize: 14, color: muted)),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(_linkedInUrl), mode: LaunchMode.externalApplication),
                child: Text(
                  'Antoan Metodiev',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.fg(0.8),
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.fg(0.25),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final icon in _socialIcons)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FaIcon(icon, size: 26, color: muted),
                ),
            ],
          ),
          const SizedBox(height: 48),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnWidth = (constraints.maxWidth - 32) / 2;
              return Wrap(
                spacing: 32,
                runSpacing: 32,
                children: [
                  for (final (titleKey, itemKeys) in _columns)
                    SizedBox(
                      width: columnWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              t(titleKey),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.fg(0.85)),
                            ),
                          ),
                          for (final key in itemKeys)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(t(key), style: TextStyle(fontSize: 14, color: muted)),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
