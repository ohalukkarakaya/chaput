import 'package:flutter/material.dart';
import 'package:chaput/core/ui/widgets/app_text_context_menu.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      contextMenuBuilder: appTextContextMenuBuilder,
      decoration: InputDecoration(labelText: label),
    );
  }
}
