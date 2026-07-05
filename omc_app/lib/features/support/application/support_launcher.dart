import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/support_config.dart';

class SupportLauncher {
  const SupportLauncher._();

  static Future<void> openWhatsApp(BuildContext context) async {
    await openWhatsAppWithMessage(
      context,
      message: SupportConfig.whatsappMessage,
    );
  }

  static Future<void> openWhatsAppWithMessage(
    BuildContext context, {
    required String message,
  }) async {
    final encodedMessage = Uri.encodeComponent(message);
    final uri = Uri.parse(
      'https://wa.me/${SupportConfig.whatsappNumber}?text=$encodedMessage',
    );

    await _launchUri(context, uri, 'Unable to open WhatsApp right now.');
  }

  static Future<void> callSupport(BuildContext context) async {
    final uri = Uri.parse('tel:${SupportConfig.phoneNumber}');
    await _launchUri(context, uri, 'Unable to start a phone call right now.');
  }

  static Future<void> emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: SupportConfig.email,
      queryParameters: const {'subject': 'OMC App Support'},
    );

    await _launchUri(context, uri, 'Unable to open email app right now.');
  }

  static Future<void> _launchUri(
    BuildContext context,
    Uri uri,
    String failureMessage,
  ) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!context.mounted) return;

      if (!launched) {
        _showFailure(context, failureMessage);
      }
    } catch (_) {
      if (!context.mounted) return;
      _showFailure(context, failureMessage);
    }
  }

  static void _showFailure(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
