import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TaxCalculatorScreen extends StatelessWidget {
  const TaxCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/services');
    });

    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
