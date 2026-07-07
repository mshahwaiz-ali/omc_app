import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/support_config.dart';

class SupportLauncher {
  const SupportLauncher._();

  static Future<void> openWhatsApp(
    BuildContext context, {
    String? phoneNumber,
    String? message,
  }) async {
    await openWhatsAppWithMessage(
      context,
      phoneNumber: phoneNumber,
      message: message ?? SupportConfig.whatsappMessage,
    );
  }

  static Future<void> openWhatsAppWithMessage(
    BuildContext context, {
    String? phoneNumber,
    required String message,
  }) async {
    final cleanNumber = _digitsOnly(phoneNumber ?? SupportConfig.whatsappNumber);
    if (cleanNumber.isEmpty) {
      _showFailure(context, 'WhatsApp support number is not configured.');
      return;
    }

    final encodedMessage = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$cleanNumber?text=$encodedMessage');

    await _launchUri(context, uri, 'Unable to open WhatsApp right now.');
  }

  static Future<void> callSupport(
    BuildContext context, {
    String? phoneNumber,
  }) async {
    final cleanNumber = (phoneNumber ?? SupportConfig.phoneNumber).trim();
    if (cleanNumber.isEmpty) {
      _showFailure(context, 'Support phone number is not configured.');
      return;
    }

    final uri = Uri.parse('tel:$cleanNumber');
    await _launchUri(context, uri, 'Unable to start a phone call right now.');
  }

  static Future<void> emailSupport(
    BuildContext context, {
    String? email,
    String subject = 'OMC App Support',
  }) async {
    final cleanEmail = (email ?? SupportConfig.email).trim();
    if (cleanEmail.isEmpty) {
      _showFailure(context, 'Support email is not configured.');
      return;
    }

    final uri = Uri(
      scheme: 'mailto',
      path: cleanEmail,
      queryParameters: {'subject': subject},
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

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static void _showFailure(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
