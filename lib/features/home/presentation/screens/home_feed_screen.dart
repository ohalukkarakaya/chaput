import 'package:flutter/material.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(context.t('home.feed_placeholder')),
    );
  }
}
