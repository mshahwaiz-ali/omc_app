import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// Lightweight loading placeholder with a subtle opacity pulse.
///
/// The pulse stops completely when the platform requests reduced motion.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = AppRadius.large,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool? _reducedMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.loadingPulse,
    );
    _opacity = Tween<double>(
      begin: 0.58,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = AppMotion.reducedMotion(context);
    if (_reducedMotion == reducedMotion) return;
    _reducedMotion = reducedMotion;

    if (reducedMotion) {
      _controller
        ..stop()
        ..value = 1;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );

    return ExcludeSemantics(
      child: _reducedMotion == true
          ? block
          : FadeTransition(opacity: _opacity, child: block),
    );
  }
}
