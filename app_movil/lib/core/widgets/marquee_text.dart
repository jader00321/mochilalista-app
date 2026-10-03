import 'package:flutter/material.dart';
import 'dart:async';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final double scrollSpeed; // Pixels per second

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(seconds: 2),
    this.scrollSpeed = 40.0,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  int _loopId = 0;

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
      _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startMarquee();
      });
    }
  }

  @override
  void dispose() {
    _loopId++; // Cancel active loop
    _scrollController.dispose();
    super.dispose();
  }

  void _startMarquee() async {
    _loopId++;
    final int currentLoop = _loopId;
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || currentLoop != _loopId) return;
    _scrollLoop(currentLoop);
  }

  void _scrollLoop(int currentLoop) async {
    if (!mounted || currentLoop != _loopId) return;
    if (_scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        
        await Future.delayed(widget.pauseDuration);
        if (!mounted || currentLoop != _loopId) return;

        final duration = Duration(milliseconds: (maxExtent / widget.scrollSpeed * 1000).toInt());
        await _scrollController.animateTo(
          maxExtent,
          duration: duration,
          curve: Curves.linear,
        );

        if (!mounted || currentLoop != _loopId) return;

        await Future.delayed(widget.pauseDuration);
        if (!mounted || currentLoop != _loopId) return;

        await _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );

        if (!mounted || currentLoop != _loopId) return;
        
        _scrollLoop(currentLoop);
      } else {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && currentLoop == _loopId) _scrollLoop(currentLoop); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), 
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}
