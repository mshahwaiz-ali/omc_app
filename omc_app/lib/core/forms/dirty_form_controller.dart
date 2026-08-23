import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DirtyFormController extends ChangeNotifier {
  bool _isDirty = false;
  bool _isSubmitting = false;
  bool _allowExit = false;

  bool get isDirty => _isDirty;
  bool get isSubmitting => _isSubmitting;
  bool get shouldBlockExit => _isDirty && !_isSubmitting && !_allowExit;

  void markDirty() => _update(dirty: true);

  void markPristine() => _update(dirty: false, allowExit: false);

  void beginSubmitting() => _update(submitting: true);

  void submissionFailed() => _update(submitting: false);

  void submissionSucceeded() =>
      _update(dirty: false, submitting: false, allowExit: true);

  void allowNextExit() => _update(allowExit: true);

  void _update({bool? dirty, bool? submitting, bool? allowExit}) {
    final nextDirty = dirty ?? _isDirty;
    final nextSubmitting = submitting ?? _isSubmitting;
    final nextAllowExit = allowExit ?? _allowExit;
    if (nextDirty == _isDirty &&
        nextSubmitting == _isSubmitting &&
        nextAllowExit == _allowExit) {
      return;
    }
    _isDirty = nextDirty;
    _isSubmitting = nextSubmitting;
    _allowExit = nextAllowExit;
    notifyListeners();
  }
}

final activeDirtyFormProvider =
    NotifierProvider<ActiveDirtyFormNotifier, DirtyFormController?>(
      ActiveDirtyFormNotifier.new,
    );

class ActiveDirtyFormNotifier extends Notifier<DirtyFormController?> {
  @override
  DirtyFormController? build() => null;

  void register(DirtyFormController controller) {
    if (!ref.mounted) return;
    state = controller;
  }

  void unregister(DirtyFormController controller) {
    if (!ref.mounted) return;
    if (identical(state, controller)) state = null;
  }
}

Future<bool> confirmDiscardActiveForm(
  BuildContext context,
  WidgetRef ref,
) async {
  final controller = ref.read(activeDirtyFormProvider);
  if (controller == null || !controller.shouldBlockExit) return true;
  final confirmed = await showDiscardChangesDialog(context);
  if (confirmed) controller.allowNextExit();
  return confirmed;
}

Future<bool> showDiscardChangesDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text(
            'You have unsaved changes. Leaving now will discard them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;
}

class UnsavedChangesGuard extends ConsumerStatefulWidget {
  const UnsavedChangesGuard({
    required this.controller,
    required this.child,
    this.onDiscardConfirmed,
    super.key,
  });

  final DirtyFormController controller;
  final Widget child;
  final Future<void> Function()? onDiscardConfirmed;

  @override
  ConsumerState<UnsavedChangesGuard> createState() =>
      _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends ConsumerState<UnsavedChangesGuard> {
  late final ActiveDirtyFormNotifier _activeDirtyFormNotifier;

  @override
  void initState() {
    super.initState();
    _activeDirtyFormNotifier = ref.read(activeDirtyFormProvider.notifier);
    widget.controller.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _register());
  }

  @override
  void didUpdateWidget(covariant UnsavedChangesGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_refresh);
    _unregisterLater(oldWidget.controller);
    widget.controller.addListener(_refresh);
    _register();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _unregisterLater(widget.controller);
    super.dispose();
  }

  void _unregisterLater(DirtyFormController controller) {
    Future<void>.microtask(() {
      try {
        _activeDirtyFormNotifier.unregister(controller);
      } on StateError {
        // The enclosing ProviderScope may already have been disposed.
      }
    });
  }

  void _register() {
    if (!mounted) return;
    _activeDirtyFormNotifier.register(widget.controller);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !widget.controller.shouldBlockExit,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !widget.controller.shouldBlockExit) return;
        final discard = await showDiscardChangesDialog(context);
        if (!discard || !context.mounted) return;
        widget.controller.allowNextExit();

        final onDiscardConfirmed = widget.onDiscardConfirmed;
        if (onDiscardConfirmed != null) {
          await onDiscardConfirmed();
          return;
        }

        if (context.mounted) {
          await Navigator.of(context).maybePop(result);
        }
      },
      child: widget.child,
    );
  }
}
