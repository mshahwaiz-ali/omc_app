import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

abstract final class E2eRecordFinders {
  static Finder requestCard(String requestId) {
    return _tappableRecordCard(requestId, description: 'service request');
  }

  static Finder taskCard(String taskId) {
    return _tappableRecordCard(taskId, description: 'ERP Task');
  }

  static Finder _tappableRecordCard(
    String recordId, {
    required String description,
  }) {
    final cleanId = recordId.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError.value(recordId, 'recordId', '$description ID is empty');
    }

    // Both Track request cards and ERP Task cards render their authoritative
    // record ID as Text inside the card's primary InkWell. A search TextField
    // may contain the same string, but it is not a descendant of that card
    // InkWell, so this finder cannot mistake typed search text for a result.
    return find.ancestor(
      of: find.text(cleanId),
      matching: find.byType(InkWell),
    );
  }
}
