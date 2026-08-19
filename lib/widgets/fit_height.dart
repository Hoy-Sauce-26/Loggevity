import 'package:flutter/material.dart';

/// Lays out [builder]'s content and, if it is taller than the space available,
/// scales the whole thing down uniformly until it fits.
///
/// This exists because estimating content height does not work reliably: the
/// same widgets render taller on Android than on iOS, and the user's text-scale
/// setting moves them again. Any layout budget built from constants is a guess,
/// and guessing low silently pushes the last row off the bottom of the screen.
/// Scaling needs no estimate - it measures the real laid-out height and adapts.
///
/// Content is never scaled up, so on a roomy screen this is a no-op. The child
/// is given the full width, so a scaled-down layout ends up slightly inset at
/// the sides - the visual cost of guaranteeing nothing is ever cut off.
class FitHeight extends StatelessWidget {
  const FitHeight({super.key, required this.builder});

  /// Receives the real constraints, so content that wants to adapt on its own
  /// terms (rather than merely being shrunk) still can.
  final Widget Function(BuildContext context, BoxConstraints constraints)
      builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth,
            child: builder(context, constraints),
          ),
        );
      },
    );
  }
}
