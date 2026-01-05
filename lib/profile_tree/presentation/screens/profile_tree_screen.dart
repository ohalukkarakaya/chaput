import 'package:flutter/material.dart';

class ProfileTreeScreen extends StatelessWidget {
  final String userId;
  const ProfileTreeScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tree of $userId')),
      body: const Center(
        child: Text('3D Tree canvas burada (MVP sonraki adım)'),
      ),
    );
  }
}