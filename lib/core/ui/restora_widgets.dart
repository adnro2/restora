import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'restora_theme.dart';

class PageBody extends StatelessWidget {
  const PageBody({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 32),
    super.key,
  });
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: padding,
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: children,
        ),
      ),
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(padding: padding, child: child),
  );
}

enum NoticeTone { info, warning, error, success }

class StatusNotice extends StatelessWidget {
  const StatusNotice({
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = NoticeTone.info,
    super.key,
  });
  final String title, message;
  final IconData icon;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      NoticeTone.warning => (RestoraColors.paleAmber, RestoraColors.amber),
      NoticeTone.error => (RestoraColors.paleDanger, RestoraColors.danger),
      _ => (RestoraColors.paleTeal, RestoraColors.ink),
    };
    return Semantics(
      container: true,
      liveRegion: tone == NoticeTone.error,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 22, color: foreground)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatePanel extends StatelessWidget {
  const StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.loading = false,
    super.key,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  final bool loading;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: SectionCard(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: RestoraColors.paleTeal,
              shape: BoxShape.circle,
            ),
            child: loading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(icon, size: 28, color: RestoraColors.teal),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RestoraColors.muted, height: 1.5),
          ),
          if (action != null) ...[
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: action!),
          ],
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: RestoraColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    ),
  );
}

/// A stylized movement illustration, never a camera preview or pose overlay.
class ElbowMotionGraphic extends StatelessWidget {
  const ElbowMotionGraphic({this.angle = 110, super.key});
  final double angle;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _ElbowPainter(angle),
      size: const Size(110, 100),
    ),
  );
}

class _ElbowPainter extends CustomPainter {
  _ElbowPainter(this.angle);
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.48);
    final radius = math.min(size.width, size.height) * 0.43;
    canvas.drawCircle(center, radius, Paint()..color = RestoraColors.paleTeal);
    final shoulder =
        center + Offset.fromDirection(math.pi * 0.75, radius * 0.8);
    final wrist =
        center +
        Offset.fromDirection(
          math.pi * 0.75 - angle.clamp(0, 180) * math.pi / 180,
          radius * 0.85,
        );
    final stroke = Paint()
      ..color = RestoraColors.teal
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(shoulder, center, stroke);
    canvas.drawLine(center, wrist, stroke);
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
    canvas.drawCircle(center, 3.5, Paint()..color = RestoraColors.teal);
    canvas.drawCircle(wrist, 5, Paint()..color = RestoraColors.ink);
  }

  @override
  bool shouldRepaint(_ElbowPainter oldDelegate) => oldDelegate.angle != angle;
}
