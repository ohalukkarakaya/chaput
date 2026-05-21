import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chaput/core/constants/app_colors.dart';
import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/legal/legal_documents.dart';
import 'package:chaput/core/router/routes.dart';
import 'package:chaput/core/ui/widgets/app_text_context_menu.dart';
import 'package:go_router/go_router.dart';

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
  String? _birthDateError;
  bool _legalAccepted = false;
  String? _legalError;

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    super.dispose();
  }

  bool _isTwoWords(String v) {
    final parts = v
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.length >= 2;
  }

  bool _validUsername(String v) {
    // a-z 0-9 _ .  (MVP)
    final re = RegExp(r'^[a-z0-9_.]{3,20}$');
    return re.hasMatch(v);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _subtractYearsClamped(DateTime value, int years) {
    final targetYear = value.year - years;
    final lastDayOfTargetMonth = DateTime(targetYear, value.month + 1, 0).day;
    final targetDay = value.day.clamp(1, lastDayOfTargetMonth);
    return DateTime(targetYear, value.month, targetDay);
  }

  DateTime _latestAllowedBirthDate() {
    return _subtractYearsClamped(_dateOnly(DateTime.now()), 13);
  }

  bool _isAtLeast13(DateTime birthDate) {
    return !_dateOnly(birthDate).isAfter(_latestAllowedBirthDate());
  }

  Future<void> _pickBirthDate() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final latestAllowed = _latestAllowedBirthDate();
    final fallbackInitial = _subtractYearsClamped(now, 20);
    final initial = _birthDate == null || _birthDate!.isAfter(latestAllowed)
        ? fallbackInitial
        : _birthDate!;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: latestAllowed,
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateError = null;
      });
    }
  }

  void _openLegalDocument(LegalDocument document) {
    final url = chaputLegalUrlForLocale(
      Localizations.localeOf(context),
      document,
    );
    context.push(
      Routes.legal,
      extra: {'title': context.t(document.titleKey), 'url': url},
    );
  }

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? false;
    setState(() {
      _birthDateError = null;
      _legalError = null;
    });

    if (!ok) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_gender == null) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_birthDate == null) {
      setState(() => _birthDateError = context.t('signup.birthdate_required'));
      HapticFeedback.heavyImpact();
      return;
    }
    if (!_isAtLeast13(_birthDate!)) {
      setState(
        () => _birthDateError = context.t('signup.age_restriction_error'),
      );
      HapticFeedback.heavyImpact();
      return;
    }
    if (!_legalAccepted) {
      setState(() => _legalError = context.t('signup.legal_required'));
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
              color: AppColors.chaputWhite.withValues(alpha: 0.88),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              border: Border.all(
                color: AppColors.chaputWhite.withValues(alpha: 0.6),
              ),
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
                              color: AppColors.chaputBlack.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () =>
                                Navigator.of(context).pop(null), // ✅ iptal
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Text(
                        context.t('signup.title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.email,
                        style: TextStyle(
                          color: AppColors.chaputBlack.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Gender selector
                      Text(
                        context.t('signup.gender'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
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
                        contextMenuBuilder: appTextContextMenuBuilder,
                        decoration: InputDecoration(
                          labelText: context.t('signup.full_name'),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) {
                            return context.t('signup.full_name_required');
                          }
                          if (!_isTwoWords(s)) {
                            return context.t('signup.full_name_two_words');
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _username,
                        textInputAction: TextInputAction.done,
                        contextMenuBuilder: appTextContextMenuBuilder,
                        decoration: InputDecoration(
                          labelText: context.t('signup.username'),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim().toLowerCase();
                          if (s.isEmpty) {
                            return context.t('signup.username_required');
                          }
                          if (!_validUsername(s)) {
                            return context.t('signup.username_invalid');
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      OutlinedButton(
                        onPressed: _pickBirthDate,
                        child: Text(
                          _birthDate == null
                              ? context.t('signup.birthdate_pick')
                              : context.t(
                                  'signup.birthdate_selected',
                                  params: {
                                    'date': _birthDate!
                                        .toIso8601String()
                                        .substring(0, 10),
                                  },
                                ),
                        ),
                      ),
                      if (_birthDateError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _birthDateError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      _LegalConsentCheckbox(
                        accepted: _legalAccepted,
                        errorText: _legalError,
                        onChanged: (value) {
                          setState(() {
                            _legalAccepted = value;
                            if (value) _legalError = null;
                          });
                        },
                        onOpenDocument: _openLegalDocument,
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
                            style: const TextStyle(
                              color: AppColors.chaputWhite,
                              fontWeight: FontWeight.w800,
                            ),
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
          border: Border.all(
            color: AppColors.chaputBlack.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.chaputWhite : AppColors.chaputBlack,
            ),
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

class _LegalConsentCheckbox extends StatelessWidget {
  const _LegalConsentCheckbox({
    required this.accepted,
    required this.errorText,
    required this.onChanged,
    required this.onOpenDocument,
  });

  final bool accepted;
  final String? errorText;
  final ValueChanged<bool> onChanged;
  final ValueChanged<LegalDocument> onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final borderColor = errorText == null
        ? AppColors.chaputBlack.withValues(alpha: 0.12)
        : Colors.redAccent.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.chaputWhite.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: accepted,
                  activeColor: AppColors.chaputBlack,
                  side: BorderSide(
                    color: AppColors.chaputBlack.withValues(alpha: 0.35),
                    width: 1.4,
                  ),
                  onChanged: (value) => onChanged(value ?? false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LegalConsentText(onOpenDocument: onOpenDocument),
              ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegalConsentText extends StatefulWidget {
  const _LegalConsentText({required this.onOpenDocument});

  final ValueChanged<LegalDocument> onOpenDocument;

  @override
  State<_LegalConsentText> createState() => _LegalConsentTextState();
}

class _LegalConsentTextState extends State<_LegalConsentText> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;
  late final TapGestureRecognizer _dataProtectionTap;
  late final TapGestureRecognizer _explicitConsentTap;
  late final TapGestureRecognizer _communityTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => widget.onOpenDocument(LegalDocument.terms);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => widget.onOpenDocument(LegalDocument.privacy);
    _dataProtectionTap = TapGestureRecognizer()
      ..onTap = () => widget.onOpenDocument(LegalDocument.dataProtection);
    _explicitConsentTap = TapGestureRecognizer()
      ..onTap = () => widget.onOpenDocument(LegalDocument.explicitConsent);
    _communityTap = TapGestureRecognizer()
      ..onTap = () => widget.onOpenDocument(LegalDocument.community);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    _dataProtectionTap.dispose();
    _explicitConsentTap.dispose();
    _communityTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: AppColors.chaputBlack.withValues(alpha: 0.72),
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    final linkStyle = baseStyle.copyWith(
      color: AppColors.chaputBlack,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationThickness: 1.4,
    );

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: context.t('signup.legal_text_before_terms')),
          TextSpan(
            text: context.t('legal.terms_title'),
            style: linkStyle,
            recognizer: _termsTap,
          ),
          TextSpan(text: context.t('signup.legal_text_after_terms')),
          TextSpan(
            text: context.t('legal.privacy_title'),
            style: linkStyle,
            recognizer: _privacyTap,
          ),
          TextSpan(text: context.t('signup.legal_text_after_privacy')),
          TextSpan(
            text: context.t('legal.data_protection_title'),
            style: linkStyle,
            recognizer: _dataProtectionTap,
          ),
          TextSpan(text: context.t('signup.legal_text_after_data_protection')),
          TextSpan(
            text: context.t('legal.explicit_consent_title'),
            style: linkStyle,
            recognizer: _explicitConsentTap,
          ),
          TextSpan(text: context.t('signup.legal_text_after_explicit_consent')),
          TextSpan(
            text: context.t('legal.community_title'),
            style: linkStyle,
            recognizer: _communityTap,
          ),
          TextSpan(text: context.t('signup.legal_text_after_community')),
        ],
      ),
    );
  }
}
