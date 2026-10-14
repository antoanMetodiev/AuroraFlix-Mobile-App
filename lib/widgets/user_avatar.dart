import 'package:flutter/material.dart';

import '../core/auth/clerk_models.dart';
import '../core/theme.dart';
import 'fade_in_image.dart';

/// Round profile picture — Clerk's avatar (it always has an image_url, a
/// generated initials image when the person hasn't uploaded one).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 32});

  final ClerkUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = [
      user.firstName,
      user.lastName,
    ].whereType<String>().where((part) => part.isNotEmpty).map((part) => part.characters.first.toUpperCase()).join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.fg(0.1)),
      clipBehavior: Clip.antiAlias,
      child: user.imageUrl != null
          ? AuroraImage(url: user.imageUrl)
          : Center(
              child: Text(
                initials.isEmpty ? (user.email ?? '?').characters.first.toUpperCase() : initials,
                style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }
}
