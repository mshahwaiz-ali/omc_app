import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/support_config.dart';

class SupportLauncher {
  const SupportLauncher._();

  static Future<void> openWhatsApp(BuildContext context) async {
    final message = Uri.encodeComponent(SupportConfig.whatsappMessage);
    final uri = Uri.parse(
      'https://wa.me/${SupportConfig.whatsappNumber}?text=$message',
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
      queryParameters: const {
        'subject': 'OMC App Support',
      },
    );

    await _launchUri(context, uri, 'Unable to open email app right now.');
  }

  static Future<void> _launchUri(
    BuildContext context,
    Uri uri,
    String failureMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }
}