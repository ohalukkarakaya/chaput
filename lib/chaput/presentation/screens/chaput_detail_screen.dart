import 'package:flutter/material.dart';

class ChaputDetailScreen extends StatelessWidget {
  final String chaputId;
  const ChaputDetailScreen({super.key, required this.chaputId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chaput $chaputId')),
      body: const Center(child: Text('Chaput detail + comments (MVP sonra)')),
    );
  }
}