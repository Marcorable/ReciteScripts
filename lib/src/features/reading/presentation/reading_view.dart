import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:maltto/src/features/reading/domain/reading_session.dart';
import 'package:maltto/src/features/reading/presentation/reading_view_model.dart';
import 'package:maltto/src/shared/design/app_tokens.dart';

part 'reading_view_components.dart';
part 'reading_script.dart';
part 'reading_terminal_states.dart';

final class ReadingView extends StatefulWidget {
  const ReadingView({required this.viewModel, super.key});

  final ReadingViewModel viewModel;

  @override
  State<ReadingView> createState() => _ReadingViewState();
}

final class _ReadingViewState extends State<ReadingView>
    with WidgetsBindingObserver {
  bool _isLeaving = false;
  late bool _platformReduceMotion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformReduceMotion = _readPlatformReduceMotion();
  }

  @override
  void didChangeAccessibilityFeatures() {
    final reduceMotion = _readPlatformReduceMotion();
    if (reduceMotion == _platformReduceMotion || !mounted) return;
    setState(() => _platformReduceMotion = reduceMotion);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.viewModel.leave());
    }
  }

  bool _readPlatformReduceMotion() => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .reduceMotion;

  Future<void> _requestLeave() async {
    if (_isLeaving) return;
    final state = widget.viewModel.state;
    if (state.status != ReadingSessionStatus.running) {
      _returnToList();
      return;
    }

    final hasProgress =
        state.currentRepetition > 1 || (state.currentWordIndex ?? 0) > 0;
    if (hasProgress && !await _confirmLeave()) return;
    if (!mounted) return;

    _isLeaving = true;
    await widget.viewModel.leave();
    if (mounted) _returnToList();
  }

  Future<bool> _confirmLeave() async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('낭독을 종료할까요?'),
        content: const Text('현재 낭독 진행은 저장되지 않습니다.'),
        actions: [
          CupertinoDialogAction(
            key: const Key('reading-leave-cancel-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 낭독'),
          ),
          CupertinoDialogAction(
            key: const Key('reading-leave-confirm-button'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _returnToList() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) || _platformReduceMotion;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestLeave());
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          automaticallyImplyLeading: false,
          middle: Text(widget.viewModel.state.scriptTitle),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.viewModel,
            builder: (context, _) {
              final state = widget.viewModel.state;
              return switch (state.status) {
                ReadingSessionStatus.running => _RunningSession(
                  state: state,
                  reduceMotion: reduceMotion,
                  onMoveBack: widget.viewModel.moveBackOneWord,
                  onLeave: _requestLeave,
                ),
                ReadingSessionStatus.completed => _CompletedSession(
                  repetitions: state.totalRepetitions,
                  elapsed: state.elapsed,
                  onReturn: _returnToList,
                ),
                ReadingSessionStatus.exited => _ExitedSession(
                  onReturn: _returnToList,
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}
