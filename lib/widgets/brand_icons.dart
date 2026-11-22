import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The five networks "Моята седмица" shares to, as app-icon style tiles
/// (website: components/recap/brand-icons.tsx): the brand's colour
/// (Instagram's gradient), a white glyph, a soft glow of the same colour.
enum ShareNetwork { instagram, facebook, whatsapp, telegram, reddit }

const networkLabels = {
  ShareNetwork.instagram: 'Instagram',
  ShareNetwork.facebook: 'Facebook',
  ShareNetwork.whatsapp: 'WhatsApp',
  ShareNetwork.telegram: 'Telegram',
  ShareNetwork.reddit: 'Reddit',
};

const _glow = {
  ShareNetwork.instagram: Color(0x8CD6249F),
  ShareNetwork.facebook: Color(0x8C1877F2),
  ShareNetwork.whatsapp: Color(0x8025D366),
  ShareNetwork.telegram: Color(0x8C29A9EB),
  ShareNetwork.reddit: Color(0x8CFF4500),
};

Gradient _background(ShareNetwork network) => switch (network) {
  ShareNetwork.instagram => const RadialGradient(
    center: Alignment(-0.4, 1.14),
    radius: 1.3,
    colors: [Color(0xFFFDF497), Color(0xFFFDF497), Color(0xFFFD5949), Color(0xFFD6249F), Color(0xFF285AEB)],
    stops: [0, 0.05, 0.45, 0.6, 0.9],
  ),
  ShareNetwork.facebook => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2D8CFF), Color(0xFF1667E0)]),
  ShareNetwork.whatsapp => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3BE27A), Color(0xFF1EBE5B)]),
  ShareNetwork.telegram => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3BB4F2), Color(0xFF1E93D6)]),
  ShareNetwork.reddit => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF6A2B), Color(0xFFFF4500)]),
};

const _glyphs = {
  ShareNetwork.instagram:
      '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" xmlns="http://www.w3.org/2000/svg"><rect x="3.5" y="3.5" width="17" height="17" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.2" cy="6.8" r="1.1" fill="#fff" stroke="none"/></svg>',
  ShareNetwork.facebook:
      '<svg viewBox="0 0 24 24" fill="#fff" xmlns="http://www.w3.org/2000/svg"><path d="M13.6 21v-7.4h2.5l.4-2.9h-2.9V8.9c0-.84.24-1.42 1.45-1.42h1.55V4.9c-.27-.04-1.19-.12-2.26-.12-2.24 0-3.77 1.37-3.77 3.88v2.04H8v2.9h2.57V21h3.03z"/></svg>',
  ShareNetwork.whatsapp:
      '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 3.5a8.5 8.5 0 0 0-7.3 12.85L3.5 20.5l4.27-1.12A8.5 8.5 0 1 0 12 3.5z" stroke="#fff" stroke-width="1.9" stroke-linejoin="round"/><path d="M9.1 7.9c-.2-.45-.4-.46-.6-.47h-.5a1 1 0 0 0-.72.34c-.25.27-.95.93-.95 2.27s.97 2.63 1.1 2.81c.14.18 1.88 3 4.64 4.08 2.3.9 2.77.72 3.26.68.5-.05 1.6-.65 1.83-1.29.22-.63.22-1.17.16-1.29-.07-.11-.25-.18-.52-.31-.27-.14-1.6-.79-1.85-.88-.25-.09-.43-.14-.61.14-.18.27-.7.88-.86 1.06-.16.18-.32.2-.59.07-.27-.14-1.15-.42-2.18-1.35-.8-.72-1.35-1.6-1.5-1.87-.16-.27-.02-.42.12-.55.12-.12.27-.32.4-.48.14-.16.18-.27.27-.45.1-.18.05-.34-.02-.48-.07-.13-.6-1.48-.84-2.02z" fill="#fff"/></svg>',
  ShareNetwork.telegram:
      '<svg viewBox="0 0 24 24" fill="#fff" xmlns="http://www.w3.org/2000/svg"><path d="M20.66 4.3 2.93 11.14c-1.21.49-1.2 1.16-.22 1.46l4.55 1.42 1.74 5.35c.21.59.11.82.73.82.48 0 .69-.22.96-.48l2.3-2.24 4.79 3.54c.88.49 1.52.24 1.74-.82l3.15-14.85c.32-1.29-.5-1.88-2.01-1.04zM8.97 13.7l9.73-6.14c.48-.29.92-.13.56.19l-8.33 7.52-.32 3.46-1.64-5.03z"/></svg>',
  ShareNetwork.reddit:
      '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><ellipse cx="12" cy="14.2" rx="7.2" ry="5.2" fill="#fff"/><circle cx="5.6" cy="11.2" r="1.7" fill="#fff"/><circle cx="18.4" cy="11.2" r="1.7" fill="#fff"/><circle cx="17.3" cy="4.6" r="1.4" fill="#fff"/><path d="M12 9 13.1 4.2l4.2.9" fill="none" stroke="#fff" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/><circle cx="9.4" cy="13.6" r="1.15" fill="#ff4500"/><circle cx="14.6" cy="13.6" r="1.15" fill="#ff4500"/><path d="M9.4 16.4c1.5 1 3.7 1 5.2 0" fill="none" stroke="#ff4500" stroke-width="1" stroke-linecap="round"/></svg>',
};

class NetworkTile extends StatelessWidget {
  const NetworkTile({super.key, required this.network, this.size = 56});

  final ShareNetwork network;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _background(network),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: _glow[network]!, blurRadius: 28, spreadRadius: -8, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // A soft top light, like an app icon.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size / 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.25), Colors.transparent],
                ),
              ),
            ),
          ),
          SvgPicture.string(_glyphs[network]!, width: size * 0.5, height: size * 0.5),
        ],
      ),
    );
  }
}
