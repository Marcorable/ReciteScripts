part of 'reading_view.dart';

final class _ReadingScript extends StatefulWidget {
  const _ReadingScript({required this.state, required this.reduceMotion});

  final ReadingSessionState state;
  final bool reduceMotion;

  @override
  State<_ReadingScript> createState() => _ReadingScriptState();
}

final class _ReadingScriptState extends State<_ReadingScript> {
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _wordKeys;
  int? _previousWordIndex;

  @override
  void initState() {
    super.initState();
    _wordKeys = _createWordKeys();
    _previousWordIndex = widget.state.currentWordIndex;
    _scheduleCurrentWordVisibility();
  }

  @override
  void didUpdateWidget(covariant _ReadingScript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.words.length != widget.state.words.length) {
      _wordKeys = _createWordKeys();
    }
    if (oldWidget.state.currentWordIndex != widget.state.currentWordIndex ||
        oldWidget.state.currentRepetition != widget.state.currentRepetition) {
      _previousWordIndex = oldWidget.state.currentWordIndex;
      _scheduleCurrentWordVisibility();
    }
  }

  List<GlobalKey> _createWordKeys() =>
      List<GlobalKey>.generate(widget.state.words.length, (_) => GlobalKey());

  void _scheduleCurrentWordVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final currentIndex = widget.state.currentWordIndex;
      if (currentIndex == null || currentIndex >= _wordKeys.length) return;
      final wordContext = _wordKeys[currentIndex].currentContext;
      final wordRenderObject = wordContext?.findRenderObject();
      final scrollRenderObject = context.findRenderObject();
      if (wordRenderObject is! RenderBox ||
          scrollRenderObject is! RenderBox ||
          !_scrollController.hasClients) {
        return;
      }
      final wordTop = wordRenderObject.localToGlobal(Offset.zero).dy;
      final wordBottom = wordRenderObject
          .localToGlobal(Offset(0, wordRenderObject.size.height))
          .dy;
      final viewportTop = scrollRenderObject.localToGlobal(Offset.zero).dy;
      final viewportBottom = scrollRenderObject
          .localToGlobal(Offset(0, scrollRenderObject.size.height))
          .dy;
      if (wordTop >= viewportTop && wordBottom <= viewportBottom) return;

      final movedBackward =
          _previousWordIndex != null && currentIndex < _previousWordIndex!;
      final viewport = RenderAbstractViewport.of(wordRenderObject);
      final target = viewport
          .getOffsetToReveal(wordRenderObject, movedBackward ? 0.15 : 0.75)
          .offset
          .clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );
      if (widget.reduceMotion) {
        _scrollController.jumpTo(target);
      } else {
        await _scrollController.animateTo(
          target,
          duration: AppMotion.scroll,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('reading-script-scroll'),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: AppSpacing.extraLarge,
      ),
      child: Wrap(
        spacing: AppSpacing.extraSmall,
        runSpacing: AppSpacing.small,
        children: [
          for (var index = 0; index < widget.state.words.length; index++)
            _ReadingWord(
              key: _wordKeys[index],
              text: widget.state.words[index],
              status: _wordStatus(index, widget.state.currentWordIndex),
              reduceMotion: widget.reduceMotion,
              isCurrent: index == widget.state.currentWordIndex,
            ),
        ],
      ),
    );
  }
}

enum _ReadingWordStatus { completed, current, pending }

_ReadingWordStatus _wordStatus(int index, int? currentWordIndex) {
  if (currentWordIndex == null || index < currentWordIndex) {
    return _ReadingWordStatus.completed;
  }
  if (index == currentWordIndex) return _ReadingWordStatus.current;
  return _ReadingWordStatus.pending;
}

final class _ReadingWord extends StatelessWidget {
  const _ReadingWord({
    required this.text,
    required this.status,
    required this.reduceMotion,
    required this.isCurrent,
    super.key,
  });

  final String text;
  final _ReadingWordStatus status;
  final bool reduceMotion;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final readingStyle = CupertinoTheme.of(context).textTheme.textStyle
        .copyWith(
          fontSize: 24,
          height: 1.45,
          fontWeight: status == _ReadingWordStatus.pending
              ? FontWeight.w400
              : FontWeight.w600,
          color: switch (status) {
            _ReadingWordStatus.completed => CupertinoColors.systemIndigo,
            _ReadingWordStatus.current => CupertinoColors.white,
            _ReadingWordStatus.pending => CupertinoColors.secondaryLabel,
          },
        );
    final label = switch (status) {
      _ReadingWordStatus.completed => '완료한 어절, $text',
      _ReadingWordStatus.current => '현재 어절, $text',
      _ReadingWordStatus.pending => '대기 중인 어절, $text',
    };
    return Semantics(
      label: label,
      liveRegion: isCurrent,
      excludeSemantics: true,
      child: AnimatedContainer(
        key: isCurrent ? const Key('reading-current-word') : null,
        duration: reduceMotion ? AppMotion.none : AppMotion.standard,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: AppSpacing.extraSmall,
        ),
        decoration: BoxDecoration(
          color: status == _ReadingWordStatus.current
              ? CupertinoColors.systemIndigo
              : CupertinoColors.systemBackground.withValues(alpha: 0),
          borderRadius: AppRadii.pill,
        ),
        child: Text(text, style: readingStyle),
      ),
    );
  }
}
