import 'package:flutter/material.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Text(context.t('auth.register_placeholder'))
      ),
    );
  }
}
