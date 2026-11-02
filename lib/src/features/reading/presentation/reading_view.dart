import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:maltto/src/features/reading/domain/reading_session.dart';
import 'package:maltto/src/features/reading/presentation/reading_view_model.dart';
import 'package:maltto/src/shared/design/app_tokens.dart';

part 'reading_view_components.dart';

final class ReadingView extends StatefulWidget {
  const ReadingView({required this.viewModel, super.key});

  final ReadingViewModel viewModel;

  @override
  State<ReadingView> createState() => _ReadingViewState();
}

final class _ReadingViewState extends State<ReadingView>
    with WidgetsBindingObserver {
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.viewModel.leave());
    }
  }

  Future<void> _leaveAndReturn() async {
    if (_isLeaving) return;
    _isLeaving = true;
    await widget.viewModel.leave();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
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
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leaveAndReturn());
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(widget.viewModel.state.scriptTitle),
          leading: CupertinoButton(
            key: const Key('reading-leave-button'),
            padding: EdgeInsets.zero,
            onPressed: _leaveAndReturn,
            child: Semantics(
              button: true,
              label: '낭독 나가기',
              excludeSemantics: true,
              child: const Text('나가기'),
            ),
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.viewModel,
            builder: (context, _) {
              final state = widget.viewModel.state;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.extraLarge),
                  child: switch (state.status) {
                    ReadingSessionStatus.running => _RunningSession(
                      state: state,
                    ),
                    ReadingSessionStatus.completed => _CompletedSession(
                      repetitions: state.totalRepetitions,
                      onReturn: _returnToList,
                    ),
                    ReadingSessionStatus.exited => _ExitedSession(
                      onReturn: _returnToList,
                    ),
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
