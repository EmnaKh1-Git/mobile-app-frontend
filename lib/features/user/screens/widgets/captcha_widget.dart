import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

class CaptchaWidget extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<bool>? onValidationChanged;

  const CaptchaWidget({
    super.key,
    required this.controller,
    this.onValidationChanged,
  });

  @override
  State<CaptchaWidget> createState() => CaptchaWidgetState();
}

class CaptchaWidgetState extends State<CaptchaWidget> {
  String _captchaCode = '';
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _generateNewCaptcha();
  }

  void _generateNewCaptcha() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buffer = StringBuffer();
    for (int i = 0; i < 5; i++) {
      buffer.write(chars[_random.nextInt(chars.length)]);
    }
    setState(() {
      _captchaCode = buffer.toString();
      widget.controller.clear();
    });
    widget.onValidationChanged?.call(false);
  }

  bool validate() {
    return widget.controller.text.trim().toUpperCase() == _captchaCode.toUpperCase();
  }

  void refresh() {
    _generateNewCaptcha();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, size: 16, color: AppColors.texte2),
              const SizedBox(width: 6),
              const Text(
                'Vérification de sécurité anti-robot',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaireDoux,
                      AppColors.accentDoux.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaire.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _captchaCode.split('').map((char) {
                    final rotation = (_random.nextDouble() - 0.5) * 0.3;
                    return Transform.rotate(
                      angle: rotation,
                      child: Text(
                        char,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: AppColors.primaire,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _generateNewCaptcha,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primaire, size: 22),
                tooltip: 'Générer un nouveau code',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Recopiez le code',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bordure),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bordure),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primaire, width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Code obligatoire';
                    }
                    if (val.trim().toUpperCase() != _captchaCode.toUpperCase()) {
                      return 'Code erroné';
                    }
                    return null;
                  },
                  onChanged: (val) {
                    final isValid = val.trim().toUpperCase() == _captchaCode.toUpperCase();
                    widget.onValidationChanged?.call(isValid);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
