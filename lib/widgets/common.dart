import 'dart:math';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme.dart';

/// Barres sonores animées, comme sur l'icône.
class WaveBars extends StatefulWidget {
  final bool animate;
  final int bars;
  final double height;
  final double barWidth;
  final bool mirrorColors;

  const WaveBars({
    super.key,
    this.animate = true,
    this.bars = 7,
    this.height = 36,
    this.barWidth = 5,
    this.mirrorColors = false,
  });

  @override
  State<WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends State<WaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant WaveBars old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.bars, (i) {
              final phase = _c.value * 2 * pi + i * 0.9;
              final base = 0.35 + 0.65 * (0.5 + 0.5 * sin(i * 1.7));
              final amp = widget.animate ? (0.55 + 0.45 * sin(phase)) : 0.5;
              final h = (widget.height * base * amp).clamp(4.0, widget.height);
              final t = widget.bars == 1 ? 0.0 : i / (widget.bars - 1);
              final color = Color.lerp(
                widget.mirrorColors ? LF.cyan : LF.magenta,
                widget.mirrorColors ? LF.blue : LF.violet,
                t,
              )!;
              return Container(
                width: widget.barWidth,
                height: h,
                margin: EdgeInsets.symmetric(horizontal: widget.barWidth * 0.45),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(widget.barWidth),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// Texte avec dégradé néon.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const GradientText(this.text,
      {super.key, required this.style, this.gradient = LF.gradient});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => gradient.createShader(r),
      child: Text(text, style: style),
    );
  }
}

/// Gros bouton à dégradé.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LF.gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: LF.violet.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 22, vertical: compact ? 10 : 15),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anneau de progression.
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Widget? child;

  const ProgressRing(
      {super.key, required this.value, this.size = 56, this.stroke = 5, this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0.0, 1.0), stroke),
        child: Center(
          child: child ??
              Text('${(value * 100).round()}%',
                  style: TextStyle(
                      fontSize: size * 0.24, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  _RingPainter(this.value, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final bg = Paint()
      ..color = LF.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, 2 * pi, false, bg);
    if (value <= 0) return;
    final fg = Paint()
      ..shader = const SweepGradient(
        colors: [LF.magenta, LF.violet, LF.blue, LF.cyan, LF.magenta],
        transform: GradientRotation(-pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, -pi / 2, 2 * pi * value, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.stroke != stroke;
}

/// Pochette générée (dégradé + initiale) pour une chanson.
class SongArt extends StatelessWidget {
  final Song song;
  final double size;
  const SongArt({super.key, required this.song, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final seed = song.title.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0xffff);
    final palettes = [
      [LF.magenta, LF.violet],
      [LF.violet, LF.blue],
      [LF.blue, LF.cyan],
      [LF.magenta, LF.blue],
    ];
    final colors = palettes[seed % palettes.length];
    final initial = song.title.trim().isEmpty
        ? '♪'
        : song.title.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
              color: Colors.white)),
    );
  }
}

/// Petite étiquette colorée.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const Pill(this.label, {super.key, this.color = LF.cyan, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

/// Ligne de chanson dans une liste.
class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final Widget? trailing;
  const SongTile({super.key, required this.song, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            SongArt(song: song),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15.5)),
                  const SizedBox(height: 2),
                  Text(song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: LF.muted, fontSize: 13)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: song.progress,
                      minHeight: 5,
                      backgroundColor: LF.border,
                      valueColor: const AlwaysStoppedAnimation(LF.cyan),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing ?? ProgressRing(value: song.progress, size: 44, stroke: 4),
          ]),
        ),
      ),
    );
  }
}
