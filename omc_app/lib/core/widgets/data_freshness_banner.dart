import 'package:flutter/material.dart';

import '../../app/theme.dart';

class DataFreshnessBanner extends StatelessWidget {
  const DataFreshnessBanner({
    super.key,
    required this.title,
    required this.message,
    this.lastSuccessAt,
    this.onRetry,
    this.retrying = false,
  });

  final String title;
  final String message;
  final DateTime? lastSuccessAt;
  final VoidCallback? onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF5C98B)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 19,
                color: Color(0xFFB25E00),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _messageWithTimestamp(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: retrying ? null : onRetry,
                icon: retrying
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 17),
                label: Text(retrying ? 'Retrying' : 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _messageWithTimestamp() {
    final timestamp = lastSuccessAt;
    if (timestamp == null) return message;
    return '$message Last synced ${_relativeAge(timestamp)}.';
  }

  String _relativeAge(DateTime timestamp) {
    final age = DateTime.now().difference(timestamp);
    if (age.isNegative || age.inSeconds < 45) return 'just now';
    if (age.inMinutes < 60) {
      final value = age.inMinutes;
      return '$value minute${value == 1 ? '' : 's'} ago';
    }
    if (age.inHours < 24) {
      final value = age.inHours;
      return '$value hour${value == 1 ? '' : 's'} ago';
    }
    final value = age.inDays;
    return '$value day${value == 1 ? '' : 's'} ago';
  }
}
