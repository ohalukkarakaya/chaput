import 'package:flutter/material.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class ProfileTreeScreen extends StatelessWidget {
  final String userId;
  const ProfileTreeScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('profile_tree.title', params: {'id': userId}))),
      body: Center(
        child: Text(context.t('profile_tree.placeholder')),
      ),
    );
  }
}
