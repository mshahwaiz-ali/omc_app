import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/mutation_intent.dart';

void main() {
  test('reuses key for the same payload and rotates when data changes', () {
    final intent = MutationIntent(random: Random(7));
    final first = intent.keyFor({'service': 'A'});

    expect(intent.keyFor({'service': 'A'}), first);
    expect(intent.keyFor({'service': 'B'}), isNot(first));
  });

  test('completion rotates the next logical submit intent', () {
    final intent = MutationIntent(random: Random(9));
    final first = intent.keyFor({'service': 'A'});
    intent.complete();

    expect(intent.keyFor({'service': 'A'}), isNot(first));
  });
}
