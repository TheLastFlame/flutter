// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'page.dart';
library;

import 'package:flutter/services.dart';
import 'package:flutter/src/material/predictive_back_builder.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'page_transitions_theme.dart';
import 'theme.dart';

/// Used by [PageTransitionsTheme] to define a [MaterialPageRoute] page
/// transition animation that looks like the default page transition used on
/// Android U and above when using predictive back.
///
/// Currently predictive back is only supported on Android U and above, and if
/// this [PageTransitionsBuilder] is used by any other platform, it will fall
/// back to [ZoomPageTransitionsBuilder].
///
/// When used on Android U and above, animates along with the back gesture to
/// reveal the destination route. Can be canceled by dragging back towards the
/// edge of the screen.
///
/// See also:
///
///  * [FadeUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android O.
///  * [OpenUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android P.
///  * [ZoomPageTransitionsBuilder], which defines the default page transition
///    that's similar to the one provided in Android Q.
///  * [CupertinoPageTransitionsBuilder], which defines a horizontal page
///    transition that matches native iOS page transitions.
class PredictiveBackPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Creates an instance of a [PageTransitionsBuilder] that matches Android U's
  /// predictive back transition.
  const PredictiveBackPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _PredictiveBackGestureDetector(
      route: route,
      builder: (BuildContext context) {
        // Only do a predictive back transition when the user is performing a
        // pop gesture. Otherwise, for things like button presses or other
        // programmatic navigation, fall back to ZoomPageTransitionsBuilder.
        if (route.popGestureInProgress) {
          return _PredictiveBackPageTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            getIsCurrent: () => route.isCurrent,
            child: child,
          );
        }

        return const ZoomPageTransitionsBuilder().buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
      },
    );
  }
}

class _PredictiveBackGestureDetector extends StatefulWidget {
  const _PredictiveBackGestureDetector({required this.route, required this.builder});

  final WidgetBuilder builder;
  final PredictiveBackRoute route;

  @override
  State<_PredictiveBackGestureDetector> createState() => _PredictiveBackGestureDetectorState();
}

class _PredictiveBackGestureDetectorState extends State<_PredictiveBackGestureDetector>
    with WidgetsBindingObserver {
  /// True when the predictive back gesture is enabled.
  bool get _isEnabled {
    return widget.route.isCurrent && widget.route.popGestureEnabled;
  }

  /// The back event when the gesture first started.
  PredictiveBackEvent? get startBackEvent => _startBackEvent;
  PredictiveBackEvent? _startBackEvent;
  set startBackEvent(PredictiveBackEvent? startBackEvent) {
    if (_startBackEvent != startBackEvent && mounted) {
      setState(() {
        _startBackEvent = startBackEvent;
      });
    }
  }

  /// The most recent back event during the gesture.
  PredictiveBackEvent? get currentBackEvent => _currentBackEvent;
  PredictiveBackEvent? _currentBackEvent;
  set currentBackEvent(PredictiveBackEvent? currentBackEvent) {
    if (_currentBackEvent != currentBackEvent && mounted) {
      setState(() {
        _currentBackEvent = currentBackEvent;
      });
    }
  }

  // Begin WidgetsBindingObserver.

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final bool gestureInProgress = !backEvent.isButtonEvent && _isEnabled;
    if (!gestureInProgress) {
      return false;
    }

    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    startBackEvent = currentBackEvent = backEvent;
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.route.handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);
    currentBackEvent = backEvent;
  }

  @override
  void handleCancelBackGesture() {
    widget.route.handleCancelBackGesture();
    startBackEvent = currentBackEvent = null;
  }

  @override
  bool handleCommitBackGesture() {
    widget.route.handleCommitBackGesture();
    startBackEvent = currentBackEvent = null;
    return false;
  }

  // End WidgetsBindingObserver.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }
}

/// Android's predictive back page transition.
class _PredictiveBackPageTransition extends StatelessWidget {
  const _PredictiveBackPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.getIsCurrent,
    required this.child,
  });

  // These values were eyeballed to match the native predictive back animation
  // on a Pixel 2 running Android API 34.
  static const double _scaleFullyOpened = 1.0;
  static const double _scaleStartTransition = 0.95;
  static const double _opacityFullyOpened = 1.0;
  static const double _opacityStartTransition = 0.95;
  static const double _weightForStartState = 65.0;
  static const double _weightForEndState = 35.0;
  static const double _screenWidthDivisionFactor = 20.0;
  static const double _xShiftAdjustment = 8.0;

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final ValueGetter<bool> getIsCurrent;
  final Widget child;

  Widget _secondaryAnimatedBuilder(BuildContext context, Widget? child) {
    final Size size = MediaQuery.sizeOf(context);
    final double screenWidth = size.width;
    final double xShift = (screenWidth / _screenWidthDivisionFactor) - _xShiftAdjustment;

    final bool isCurrent = getIsCurrent();
    final Tween<double> xShiftTween =
        isCurrent ? ConstantTween<double>(0) : Tween<double>(begin: xShift, end: 0);
    final Animatable<double> scaleTween =
        isCurrent
            ? ConstantTween<double>(_scaleFullyOpened)
            : TweenSequence<double>(<TweenSequenceItem<double>>[
              TweenSequenceItem<double>(
                tween: Tween<double>(begin: _scaleStartTransition, end: _scaleFullyOpened),
                weight: _weightForStartState,
              ),
              TweenSequenceItem<double>(
                tween: Tween<double>(begin: _scaleFullyOpened, end: _scaleFullyOpened),
                weight: _weightForEndState,
              ),
            ]);
    final Animatable<double> fadeTween =
        isCurrent
            ? ConstantTween<double>(_opacityFullyOpened)
            : TweenSequence<double>(<TweenSequenceItem<double>>[
              TweenSequenceItem<double>(
                tween: Tween<double>(begin: _opacityFullyOpened, end: _opacityStartTransition),
                weight: _weightForStartState,
              ),
              TweenSequenceItem<double>(
                tween: Tween<double>(begin: _opacityFullyOpened, end: _opacityFullyOpened),
                weight: _weightForEndState,
              ),
            ]);

    return Transform.translate(
      offset: Offset(xShiftTween.animate(secondaryAnimation).value, 0),
      child: Transform.scale(
        scale: scaleTween.animate(secondaryAnimation).value,
        child: Opacity(opacity: fadeTween.animate(secondaryAnimation).value, child: child),
      ),
    );
  }

  Widget _primaryAnimatedBuilder(BuildContext context, Widget? child) {
    final Size size = MediaQuery.sizeOf(context);
    final double screenWidth = size.width;
    final double xShift = (screenWidth / _screenWidthDivisionFactor) - _xShiftAdjustment;

    final Animatable<double> xShiftTween = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 0.0),
        weight: _weightForStartState,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: xShift, end: 0.0),
        weight: _weightForEndState,
      ),
    ]);
    final Animatable<double> scaleTween = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: _scaleFullyOpened, end: _scaleFullyOpened),
        weight: _weightForStartState,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: _scaleStartTransition, end: _scaleFullyOpened),
        weight: _weightForEndState,
      ),
    ]);
    final Animatable<double> fadeTween = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 0.0),
        weight: _weightForStartState,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: _opacityStartTransition, end: _opacityFullyOpened),
        weight: _weightForEndState,
      ),
    ]);

    return Transform.translate(
      offset: Offset(xShiftTween.animate(animation).value, 0),
      child: Transform.scale(
        scale: scaleTween.animate(animation).value,
        child: Opacity(opacity: fadeTween.animate(animation).value, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: secondaryAnimation,
      builder: _secondaryAnimatedBuilder,
      child: AnimatedBuilder(animation: animation, builder: _primaryAnimatedBuilder, child: child),
    );
  }
}

class PredictiveBackPageSharedElementTransitionsBuilder extends PageTransitionsBuilder {
  /// Creates an instance of a [PageTransitionsBuilder] that matches Android U's
  /// predictive back transition.
  PredictiveBackPageSharedElementTransitionsBuilder({
    this.backgroundColor,
    PageTransitionsBuilder? parentTransitionsBuilder,
  }) : parentTransitionsBuilder =
           parentTransitionsBuilder ??
           FadeForwardsPageTransitionsBuilder(backgroundColor: backgroundColor);

  final PageTransitionsBuilder parentTransitionsBuilder;
  final Color? backgroundColor;

  @override
  Duration get transitionDuration => parentTransitionsBuilder.transitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return PredictiveBackGestureBuilder(
      updateRouteUserGestureProgress: route.isCurrent,
      transitionBuilder: (
        BuildContext context,
        PredictiveBackPhase phase,
        PredictiveBackEvent? startBackEvent,
        PredictiveBackEvent? currentBackEvent,
        Animation<double> predictiveAnimation,
        Widget child,
      ) {
        return _PredictiveBackPageSharedElementTransition(
          route: route,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          phase: phase,
          startBackEvent: startBackEvent,
          currentBackEvent: currentBackEvent,
          predictiveAnimation: predictiveAnimation,
          parentPageTransitionBuilder: parentTransitionsBuilder,
          backgroundColor: backgroundColor,
          child: child,
        );
      },
      child: child,
    );
  }
}

class _PredictiveBackPageSharedElementTransition extends StatefulWidget {
  const _PredictiveBackPageSharedElementTransition({
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
    required this.phase,
    this.startBackEvent,
    this.currentBackEvent,
    required this.predictiveAnimation,
    required this.child,
    required this.parentPageTransitionBuilder,
    this.backgroundColor,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final PredictiveBackPhase phase;
  final PredictiveBackEvent? startBackEvent;
  final PredictiveBackEvent? currentBackEvent;
  final Animation<double> predictiveAnimation;
  final PageTransitionsBuilder parentPageTransitionBuilder;
  final Color? backgroundColor;
  final Widget child;

  @override
  State<_PredictiveBackPageSharedElementTransition> createState() =>
      _PredictiveBackPageSharedElementTransitionState();
}

class _PredictiveBackPageSharedElementTransitionState
    extends State<_PredictiveBackPageSharedElementTransition>
    with TickerProviderStateMixin {
  late final AnimationController commitController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );

  @override
  void didUpdateWidget(_PredictiveBackPageSharedElementTransition oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.phase == oldWidget.phase) {
      return;
    }

    if (widget.phase == PredictiveBackPhase.commit && !commitController.isAnimating) {
      commitController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    commitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: commitController,
      builder: (BuildContext context, Widget? child) {
        if (widget.route.popGestureInProgress) {
          final PredictiveBackPageSharedElementFrame predictiveFrame =
              PredictiveBackPageSharedElementFrame(
                animation: widget.predictiveAnimation,
                startBackEvent: widget.startBackEvent,
                currentBackEvent: widget.currentBackEvent,
                child: widget.child,
              );

          if (widget.route.isCurrent) {
            return ColoredBox(color: Colors.black54, child: predictiveFrame);
          }

          if (widget.secondaryAnimation.isAnimating) {
            return ColoredBox(
              color: widget.backgroundColor ?? Theme.of(context).colorScheme.surface,
              child: Transform.translate(offset: const Offset(-100, 0), child: predictiveFrame),
            );
          }
        }

        if (commitController.isAnimating) {
          final PredictiveBackPageSharedElementFrame predictiveFrame =
              PredictiveBackPageSharedElementFrame(
                animation: widget.predictiveAnimation,
                startBackEvent: widget.startBackEvent,
                currentBackEvent: widget.currentBackEvent,
                suppressionFactor: 1 - commitController.value,
                child: widget.child,
              );

          if (!widget.route.isActive) {
            return Opacity(
              opacity: 1 - commitController.value,
              child: ColoredBox(
                color: Colors.black54,
                child: Transform.translate(
                  offset: Offset(100 * commitController.value, 0),
                  child: predictiveFrame,
                ),
              ),
            );
          }
          if (widget.route.isCurrent) {
            return ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Transform.translate(
                offset: Offset(-100 * (1 - commitController.value), 0),
                child: predictiveFrame,
              ),
            );
          }
        }

        return widget.parentPageTransitionBuilder.buildTransitions(
          widget.route,
          context,
          widget.animation,
          widget.secondaryAnimation,
          widget.child,
        );
      },
    );
  }
}
