import 'dart:convert';
import 'dart:math';

class MutationIntent {
  MutationIntent({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  String? _key;
  String? _payloadFingerprint;

  String keyFor(Object? payload) {
    final fingerprint = jsonEncode(payload);
    if (_key == null || _payloadFingerprint != fingerprint) {
      _key = _newKey();
      _payloadFingerprint = fingerprint;
    }
    return _key!;
  }

  void complete() {
    _key = null;
    _payloadFingerprint = null;
  }

  String _newKey() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final randomPart = List.generate(
      24,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();
    return 'omc-$timestamp-$randomPart';
  }
}
