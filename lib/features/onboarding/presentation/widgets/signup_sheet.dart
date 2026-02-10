import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chaput/core/constants/app_colors.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class SignupDraft {
  final String gender; // "M" | "F"
  final String fullName;
  final String username;
  final DateTime birthDate;

  SignupDraft({
    required this.gender,
    required this.fullName,
    required this.username,
    required this.birthDate,
  });
}

Future<SignupDraft?> showSignupSheet({
  required BuildContext context,
  required String email,
}) {
  return showModalBottomSheet<SignupDraft?>(
    context: context,
    isScrollControlled: true,
    isDismissible: true, // ✅ kapatılabilir
    enableDrag: true,
    backgroundColor: AppColors.chaputTransparent,
    builder: (_) => _SignupSheet(email: email),
  );
}

class _SignupSheet extends StatefulWidget {
  final String email;
  const _SignupSheet({required this.email});

  @override
  State<_SignupSheet> createState() => _SignupSheetState();
}

class _SignupSheetState extends State<_SignupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();

  String? _gender; // "M"|"F"
  DateTime? _birthDate;

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    super.dispose();
  }

  bool _isTwoWords(String v) {
    final parts = v.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return parts.length >= 2;
  }

  bool _validUsername(String v) {
    // a-z 0-9 _ .  (MVP)
    final re = RegExp(r'^[a-z0-9_.]{3,20}$');
    return re.hasMatch(v);
  }

  Future<void> _pickBirthDate() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 20, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year - 10, 12, 31),
    );

    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_gender == null || _birthDate == null) {
      HapticFeedback.heavyImpact();
      return;
    }

    Navigator.of(context).pop(
      SignupDraft(
        gender: _gender!,
        fullName: _fullName.text.trim(),
        username: _username.text.trim(),
        birthDate: _birthDate!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.chaputWhite.withOpacity(0.88),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: AppColors.chaputWhite.withOpacity(0.6)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.chaputBlack.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(null), // ✅ iptal
                            icon: const Icon(Icons.close),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),

                      Text(
                        context.t('signup.title'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.email,
                        style: TextStyle(color: AppColors.chaputBlack.withOpacity(0.6)),
                      ),
                      const SizedBox(height: 14),

                      // Gender selector
                      Text(context.t('signup.gender'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _GenderButton(
                              selected: _gender == 'M',
                              icon: Icons.male,
                              label: context.t('signup.gender_male'),
                              onTap: () => setState(() => _gender = 'M'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GenderButton(
                              selected: _gender == 'F',
                              icon: Icons.female,
                              label: context.t('signup.gender_female'),
                              onTap: () => setState(() => _gender = 'F'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _fullName,
                        decoration: InputDecoration(
                          labelText: context.t('signup.full_name'),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return context.t('signup.full_name_required');
                          if (!_isTwoWords(s)) return context.t('signup.full_name_two_words');
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _username,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: context.t('signup.username'),
                          helperText: context.t('signup.username_hint'),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim().toLowerCase();
                          if (s.isEmpty) return context.t('signup.username_required');
                          if (!_validUsername(s)) return context.t('signup.username_invalid');
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      OutlinedButton(
                        onPressed: _pickBirthDate,
                        child: Text(
                          _birthDate == null
                              ? context.t('signup.birthdate_pick')
                              : context.t('signup.birthdate_selected', params: {
                                  'date': _birthDate!.toIso8601String().substring(0, 10),
                                }),
                        ),
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.chaputBlack,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            context.t('common.continue'),
                            style: const TextStyle(color: AppColors.chaputWhite, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GenderButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: selected ? AppColors.chaputBlack : AppColors.chaputWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.chaputBlack.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? AppColors.chaputWhite : AppColors.chaputBlack),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.chaputWhite : AppColors.chaputBlack,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
