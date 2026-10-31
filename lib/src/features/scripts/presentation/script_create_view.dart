import 'package:flutter/cupertino.dart';
import 'package:maltto/src/features/scripts/presentation/script_create_view_model.dart';
import 'package:maltto/src/shared/design/app_tokens.dart';

final class ScriptCreateView extends StatefulWidget {
  const ScriptCreateView({required this.viewModel, super.key});

  final ScriptCreateViewModel viewModel;

  @override
  State<ScriptCreateView> createState() => _ScriptCreateViewState();
}

final class _ScriptCreateViewState extends State<ScriptCreateView> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _bodyFocusNode = FocusNode();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    widget.viewModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await widget.viewModel.save(
      title: _titleController.text,
      body: _bodyController.text,
    );
    if (!mounted) return;
    if (!saved) {
      if (widget.viewModel.titleError != null) {
        _titleFocusNode.requestFocus();
      } else if (widget.viewModel.bodyError != null) {
        _bodyFocusNode.requestFocus();
      }
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('대본 추가'),
        leading: ConstrainedBox(
          constraints: AppTargets.preferredConstraints,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: Semantics(
              button: true,
              label: '대본 추가 취소',
              excludeSemantics: true,
              child: const Text('취소'),
            ),
          ),
        ),
        trailing: AnimatedBuilder(
          animation: widget.viewModel,
          builder: (context, child) => ConstrainedBox(
            constraints: AppTargets.preferredConstraints,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: widget.viewModel.isSaving ? null : _save,
              child: widget.viewModel.isSaving
                  ? const CupertinoActivityIndicator()
                  : Semantics(
                      button: true,
                      label: '대본 저장',
                      excludeSemantics: true,
                      child: const Text('저장'),
                    ),
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.viewModel,
          builder: (context, child) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.large,
                AppSpacing.extraLarge,
                AppSpacing.large,
                AppSpacing.section,
              ),
              children: [
                _FieldLabel(
                  label: '제목',
                  child: Semantics(
                    textField: true,
                    label: '제목',
                    child: CupertinoTextField(
                      key: const Key('script-title-field'),
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      placeholder: '제목을 입력하세요',
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _bodyFocusNode.requestFocus(),
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      clearButtonMode: OverlayVisibilityMode.editing,
                    ),
                  ),
                ),
                if (widget.viewModel.titleError case final error?)
                  _ValidationMessage(message: error),
                const SizedBox(height: AppSpacing.extraLarge),
                _FieldLabel(
                  label: '본문',
                  child: Semantics(
                    textField: true,
                    label: '본문',
                    child: CupertinoTextField(
                      key: const Key('script-body-field'),
                      controller: _bodyController,
                      focusNode: _bodyFocusNode,
                      placeholder: '읽을 내용을 입력하세요',
                      minLines: 10,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      padding: const EdgeInsets.all(AppSpacing.medium),
                    ),
                  ),
                ),
                if (widget.viewModel.bodyError case final error?)
                  _ValidationMessage(message: error),
                if (widget.viewModel.saveError case final error?) ...[
                  const SizedBox(height: AppSpacing.extraLarge),
                  Semantics(
                    liveRegion: true,
                    child: _ValidationMessage(message: error),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
        const SizedBox(height: AppSpacing.small),
        child,
      ],
    );
  }
}

final class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.small),
      child: Text(
        message,
        style: const TextStyle(color: CupertinoColors.systemRed),
      ),
    );
  }
}
