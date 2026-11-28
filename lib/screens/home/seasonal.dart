import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/locale.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';

/// Seasonal themes, switched on by date (website: lib/seasons.ts): light
/// particles over the home screen, with an on/off switch.
enum Season { winter, halloween, valentine }

Season? activeSeason([DateTime? now]) {
  final date = now ?? DateTime.now();
  final key = date.month * 100 + date.day;
  // Christmas markets and lights go up in the second half of November.
  if (key >= 1120 || key <= 106) return Season.winter;
  if (key >= 1020 && key <= 1101) return Season.halloween;
  if (key >= 207 && key <= 215) return Season.valentine;
  return null;
}

const _fxKey = 'aurora-seasonal-fx';

/// The particles switch — on unless the viewer turned it off; remembered.
class SeasonalFx extends Notifier<bool> {
  @override
  bool build() => ref.read(sharedPreferencesProvider).getString(_fxKey) != 'off';

  void toggle() {
    state = !state;
    ref.read(sharedPreferencesProvider).setString(_fxKey, state ? 'on' : 'off');
  }
}

final seasonalFxProvider = NotifierProvider<SeasonalFx, bool>(SeasonalFx.new);

/// The particles' on/off switch (website: SeasonalToggle) — next to the
/// "Your week" pill on the home screen, only while a season is on. Icon-only
/// on phones, where it shares that row with the pill. (The season's themed
/// row of titles it used to sit on was removed on 2026-11-28, same as the
/// website: no more themed selections.)
class SeasonalToggle extends ConsumerWidget {
  const SeasonalToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activeSeason() == null) return const SizedBox.shrink();
    final t = ref.watch(translatorProvider);
    final on = ref.watch(seasonalFxProvider);
    final label = t(on ? 'seasonal.fxOff' : 'seasonal.fxOn');
    final wide = MediaQuery.sizeOf(context).width >= 640;
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: () => ref.read(seasonalFxProvider.notifier).toggle(),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.fg(0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.fg(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.sparkles, size: 13, color: AppColors.fg(0.7)),
              if (wide) ...[
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.fg(0.7))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Snow in winter, rising embers at Halloween, falling hearts at
/// Valentine's (website: SeasonalEffects): a few dozen particles on one
/// CustomPaint, touch-transparent. Off with reduced motion or the switch.
class SeasonalEffects extends ConsumerStatefulWidget {
  const SeasonalEffects({super.key});

  @override
  ConsumerState<SeasonalEffects> createState() => _SeasonalEffectsState();
}

class _Particle {
  _Particle(this.x, this.y, this.size, this.speed, this.drift, this.alpha);
  double x;
  double y;
  final double size;
  final double speed;
  double drift;
  final double alpha;
}

class _SeasonalEffectsState extends ConsumerState<SeasonalEffects> with SingleTickerProviderStateMixin {
  final _random = math.Random();
  final _particles = <_Particle>[];
  final _repaint = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  Size _size = Size.zero;
  final Season? _season = activeSeason();

  _Particle _spawn(bool anywhere) {
    final winter = _season == Season.winter;
    return _Particle(
      _random.nextDouble() * _size.width,
      anywhere ? _random.nextDouble() * _size.height : (_season == Season.halloween ? _size.height + 10 : -10),
      winter ? 1 + _random.nextDouble() * 2.6 : 6 + _random.nextDouble() * 8,
      (winter ? 0.35 : 0.25) + _random.nextDouble() * 0.6,
      _random.nextDouble() * math.pi * 2,
      0.35 + _random.nextDouble() * 0.5,
    );
  }

  void _tick(Duration elapsed) {
    final dt = math.min(3.0, (elapsed - _last).inMicroseconds / 16700);
    _last = elapsed;
    if (_size.isEmpty) return;
    for (var i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      p.drift += 0.012 * dt;
      p.x += math.sin(p.drift) * 0.35 * dt;
      p.y += (_season == Season.halloween ? -p.speed : p.speed) * dt;
      if (p.y > _size.height + 12 || p.y < -12 || p.x < -12 || p.x > _size.width + 12) _particles[i] = _spawn(false);
    }
    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _season != null && ref.watch(seasonalFxProvider) && !MediaQuery.of(context).disableAnimations;
    if (!enabled) {
      if (_ticker.isActive) _ticker.stop();
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size != _size) {
          _size = size;
          final count = (math.min(70.0, math.max(24.0, size.width / 22)) * (_season == Season.winter ? 1 : 0.45)).round();
          _particles
            ..clear()
            ..addAll(List.generate(count, (_) => _spawn(true)));
        }
        if (!_ticker.isActive) {
          _last = Duration.zero;
          _ticker.start();
        }
        return IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(size: size, painter: _ParticlePainter(_particles, _season, _repaint)),
          ),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, this.season, Listenable repaint) : super(repaint: repaint);

  final List<_Particle> particles;
  final Season season;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      switch (season) {
        case Season.winter:
          canvas.drawCircle(Offset(p.x, p.y), p.size, Paint()..color = Colors.white.withValues(alpha: p.alpha));
        case Season.halloween:
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size / 4,
            Paint()
              ..color = const Color(0xFFFB923C).withValues(alpha: p.alpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        case Season.valentine:
          final s = p.size / 2;
          final path = Path()
            ..moveTo(p.x, p.y + s * 0.6)
            ..cubicTo(p.x - s * 1.2, p.y - s * 0.2, p.x - s * 0.5, p.y - s * 1.1, p.x, p.y - s * 0.4)
            ..cubicTo(p.x + s * 0.5, p.y - s * 1.1, p.x + s * 1.2, p.y - s * 0.2, p.x, p.y + s * 0.6);
          canvas.drawPath(path, Paint()..color = const Color(0xFFFB7185).withValues(alpha: p.alpha));
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => false;
}
