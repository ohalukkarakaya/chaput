import 'package:flutter/material.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class ChaputDetailScreen extends StatelessWidget {
  final String chaputId;
  const ChaputDetailScreen({super.key, required this.chaputId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('chaput.detail_title', params: {'id': chaputId}))),
      body: Center(child: Text(context.t('chaput.detail_placeholder'))),
    );
  }
}
