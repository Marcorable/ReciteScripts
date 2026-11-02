import 'package:flutter/cupertino.dart';
import 'package:maltto/src/features/reading/presentation/reading_setup_view_model.dart';
import 'package:maltto/src/features/reading/presentation/reading_view.dart';
import 'package:maltto/src/features/reading/presentation/reading_view_model.dart';
import 'package:maltto/src/shared/design/app_tokens.dart';

final class ReadingSetupView extends StatefulWidget {
  const ReadingSetupView({required this.viewModel, super.key});

  final ReadingSetupViewModel viewModel;

  @override
  State<ReadingSetupView> createState() => _ReadingSetupViewState();
}

final class _ReadingSetupViewState extends State<ReadingSetupView> {
  late final FixedExtentScrollController _pickerController;

  @override
  void initState() {
    super.initState();
    _pickerController = FixedExtentScrollController(
      initialItem: widget.viewModel.repetitions - 1,
    );
  }

  Future<void> _start() async {
    final initialState = await widget.viewModel.start();
    if (!mounted || initialState == null) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => ReadingView(
          viewModel: ReadingViewModel(
            repository: widget.viewModel.repository,
            initialState: initialState,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pickerController.dispose();
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaledPickerTextHeight = MediaQuery.textScalerOf(context).scale(22);
    final accessiblePickerItemExtent =
        scaledPickerTextHeight + AppSpacing.extraLarge;
    final pickerItemExtent = accessiblePickerItemExtent > AppTargets.preferred
        ? accessiblePickerItemExtent
        : AppTargets.preferred;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('낭독 시작')),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.viewModel,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.extraLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '선택한 대본',
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  widget.viewModel.script.title,
                  key: const Key('reading-setup-script-title'),
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                ),
                if (widget.viewModel.startIssue case final issue?) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _startIssueMessage(issue),
                      key: const Key('reading-setup-start-status'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.section),
                Semantics(
                  container: true,
                  label: '반복 횟수, ${widget.viewModel.repetitions}회 선택됨',
                  child: Column(
                    children: [
                      const Text('반복 횟수'),
                      SizedBox(
                        height: 192,
                        child: CupertinoPicker.builder(
                          key: const Key('reading-repetition-picker'),
                          scrollController: _pickerController,
                          itemExtent: pickerItemExtent,
                          useMagnifier: true,
                          magnification: 1.08,
                          childCount: 10,
                          onSelectedItemChanged: (index) =>
                              widget.viewModel.selectRepetitions(index + 1),
                          itemBuilder: (_, index) =>
                              Center(child: Text('${index + 1}회')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                Row(
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: AppTargets.preferredConstraints,
                        child: CupertinoButton(
                          key: const Key('reading-setup-cancel-button'),
                          onPressed: widget.viewModel.isStarting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('취소'),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: AppTargets.preferredConstraints,
                        child: CupertinoButton.filled(
                          key: const Key('reading-setup-start-button'),
                          onPressed: widget.viewModel.isStarting
                              ? null
                              : _start,
                          child: widget.viewModel.isStarting
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white,
                                )
                              : const Text('시작'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _startIssueMessage(ReadingSetupStartIssue issue) => switch (issue) {
    ReadingSetupStartIssue.permissionRequired =>
      '마이크와 음성 인식 권한을 허용한 뒤 다시 시작해 주세요.',
    ReadingSetupStartIssue.modelPreparing =>
      '한국어 음성 모델을 준비 중입니다. 준비가 끝나면 다시 시작해 주세요.',
    ReadingSetupStartIssue.unsupported => '이 기기에서 온디바이스 한국어 음성 인식을 사용할 수 없습니다.',
    ReadingSetupStartIssue.temporaryFailure =>
      '음성 인식을 준비하지 못했습니다. 잠시 후 다시 시작해 주세요.',
  };
}
