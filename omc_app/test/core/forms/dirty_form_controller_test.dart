import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/forms/dirty_form_controller.dart';

void main() {
  test('dirty form blocks exit until explicitly allowed', () {
    final controller = DirtyFormController();

    expect(controller.shouldBlockExit, isFalse);
    controller.markDirty();
    expect(controller.shouldBlockExit, isTrue);
    controller.allowNextExit();
    expect(controller.shouldBlockExit, isFalse);
  });

  test('submission state controls exit and terminal state', () {
    final controller = DirtyFormController()..markDirty();

    controller.beginSubmitting();
    expect(controller.shouldBlockExit, isFalse);
    controller.submissionFailed();
    expect(controller.shouldBlockExit, isTrue);
    controller.submissionSucceeded();
    expect(controller.isDirty, isFalse);
    expect(controller.shouldBlockExit, isFalse);
  });

  test('marking pristine resets a previous exit allowance', () {
    final controller = DirtyFormController()
      ..markDirty()
      ..allowNextExit()
      ..markPristine()
      ..markDirty();

    expect(controller.shouldBlockExit, isTrue);
  });
}
