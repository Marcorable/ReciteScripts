import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:maltto/src/shared/design/app_tokens.dart';

bool get usesExpandedNavigationActions =>
    defaultTargetPlatform == TargetPlatform.android;

final class ScriptNavigationActionBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ScriptNavigationActionBar({
    this.leading,
    required this.trailing,
    super.key,
  });

  final Widget? leading;
  final Widget trailing;

  @override
  Size get preferredSize => const Size.fromHeight(AppTargets.preferred);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTargets.preferred,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
        child: Row(children: [?leading, const Spacer(), trailing]),
      ),
    );
  }
}

final class ScriptNavigationButton extends StatelessWidget {
  const ScriptNavigationButton({
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: AppTargets.preferredConstraints,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
        onPressed: onPressed,
        child: Semantics(
          button: true,
          label: semanticLabel,
          excludeSemantics: true,
          child: child,
        ),
      ),
    );
  }
}
