import 'package:flutter/material.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class ChaputComposeScreen extends StatelessWidget {
  const ChaputComposeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(context.t('chaput.compose_placeholder'))),
    );
  }
}
