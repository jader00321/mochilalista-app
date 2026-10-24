import 'package:flutter/material.dart';
import 'dart:async';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final double scrollSpeed; // Pixels per second
  final VoidCallback? onTap;
  final bool enableGradientFade;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(seconds: 2),
    this.scrollSpeed = 40.0,
    this.onTap,
    this.enableGradientFade = true,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  int _loopId = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMarquee();
    });
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _loopId++; // Cancel active loop
      _timer?.cancel();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startMarquee();
      });
    }
  }

  @override
  void dispose() {
    _loopId++; // Cancel active loop
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _safeDelay(Duration duration, int currentLoop) {
    final completer = Completer<void>();
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  void _startMarquee() async {
    _loopId++;
    final int currentLoop = _loopId;
    if (!mounted) return;
    await _safeDelay(widget.pauseDuration, currentLoop);
    if (!mounted || currentLoop != _loopId) return;
    _scrollLoop(currentLoop);
  }

  void _scrollLoop(int currentLoop) async {
    if (!mounted || currentLoop != _loopId) return;
    if (_scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        await _safeDelay(widget.pauseDuration, currentLoop);
        if (!mounted || currentLoop != _loopId) return;

        final duration = Duration(milliseconds: (maxExtent / widget.scrollSpeed * 1000).toInt());
        await _scrollController.animateTo(
          maxExtent,
          duration: duration,
          curve: Curves.linear,
        );

        if (!mounted || currentLoop != _loopId) return;

        await _safeDelay(widget.pauseDuration, currentLoop);
        if (!mounted || currentLoop != _loopId) return;

        await _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );

        if (!mounted || currentLoop != _loopId) return;
        
        _scrollLoop(currentLoop);
      } else {
        await _safeDelay(const Duration(seconds: 4), currentLoop);
        if (mounted && currentLoop == _loopId) _scrollLoop(currentLoop); 
      }
    } else {
      await _safeDelay(const Duration(milliseconds: 300), currentLoop);
      if (mounted && currentLoop == _loopId) _scrollLoop(currentLoop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrollChild = SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), 
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );

    final marquee = widget.enableGradientFade
        ? ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0.0, 0.04, 0.96, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: scrollChild,
          )
        : scrollChild;

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: marquee,
      );
    }
    return marquee;
  }
}
