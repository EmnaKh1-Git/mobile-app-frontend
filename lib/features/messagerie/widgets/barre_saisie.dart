import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

import '../services/audio_service.dart';
import '../services/messagerie_service.dart';

import 'enregistreur_vocal.dart';

// ============================================================
// BARRE DE SAISIE — texte ou message vocal
// ============================================================

class BarreSaisie extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onEnvoyer;
  final String conversationId;
  final bool enabled;

  /// Explication affichée si le micro est désactivé.
  final String? motifMicroDesactive;

  /// Appelé après l'envoi d'un vocal (pour défiler en bas).
  final VoidCallback? onVocalEnvoye;

  const BarreSaisie({
    super.key,
    required this.controller,
    required this.onEnvoyer,
    required this.conversationId,
    this.enabled = true,
    this.motifMicroDesactive,
    this.onVocalEnvoye,
  });

  @override
  State<BarreSaisie> createState() => _BarreSaisieState();
}

class _BarreSaisieState extends State<BarreSaisie> {
  bool _enregistrement = false;
  int _secondes = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    AudioService.instance.dispose();
    super.dispose();
  }

  bool get _microActif =>
      widget.enabled && widget.motifMicroDesactive == null;

  // ---------------------------------------------------------
  // ENREGISTREMENT
  // ---------------------------------------------------------

  Future<void> _demarrerEnregistrement() async {
    if (!_microActif || _enregistrement) return;

    final autorise = await AudioService.instance.demanderPermission();
    if (!autorise) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Autorisez le micro pour envoyer un vocal',
          ),
        ),
      );
      return;
    }

    if (mounted) {
      FocusScope.of(context).unfocus();
    }

    try {
      await AudioService.instance.demarrerEnregistrement();
    } catch (_) {
      if (!mounted) return;
      return;
    }

    if (!mounted) return;
    setState(() {
      _enregistrement = true;
      _secondes = 0;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _secondes++;
        });

        // Durée max : arrêt et envoi automatiques.
        if (_secondes >=
            MessagerieService.dureeMaxVocalSecondes) {
          _envoyerVocal();
        }
      },
    );
  }

  Future<void> _annuler() async {
    _timer?.cancel();
    await AudioService.instance.annulerEnregistrement();
    if (!mounted) return;

    setState(() {
      _enregistrement = false;
      _secondes = 0;
    });
  }

  Future<void> _envoyerVocal() async {
    final duree = _secondes;

    _timer?.cancel();

    if (duree < MessagerieService.dureeMinVocalSecondes) {
      await AudioService.instance.annulerEnregistrement();
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _secondes = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message trop court')),
      );
      return;
    }

    String? chemin;
    try {
      chemin = await AudioService.instance.arreterEnregistrement();
    } catch (_) {
      chemin = null;
    }

    if (chemin != null) {
      AudioService.instance.setDernierCheminEnregistre(chemin);
    }

    if (!mounted) return;

    setState(() {
      _enregistrement = false;
      _secondes = 0;
    });

    try {
      await MessagerieService.instance.envoyerVocal(
        widget.conversationId,
        duree,
        chemin,
      );
    } on MessagerieException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    widget.onVocalEnvoye?.call();
  }

  // ---------------------------------------------------------
  // BOUTONS
  // ---------------------------------------------------------

  Widget _boutonEnvoyer() {
    return SizedBox(
      width: 48,
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 48),
          backgroundColor: AppColors.primaire,
        ),
        onPressed: widget.enabled
            ? widget.onEnvoyer
            : null,
        child: const Icon(
          Icons.send,
          size: 20,
        ),
      ),
    );
  }

  Widget _boutonMicro() {
    final motif = widget.motifMicroDesactive ??
        (widget.enabled ? null : 'Envoi désactivé.');

    final bouton = SizedBox(
      width: 48,
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 48),
          backgroundColor: AppColors.primaire,
        ),
        onPressed:
            _microActif ? _demarrerEnregistrement : null,
        child: const Icon(
          Icons.mic,
          size: 20,
        ),
      ),
    );

    if (motif == null) return bouton;

    return Tooltip(
      message: motif,
      child: bouton,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_enregistrement) {
      return EnregistreurVocal(
        dureeSecondes: _secondes,
        onAnnuler: _annuler,
        onEnvoyer: _envoyerVocal,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.bordure,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.bordure,
                ),
              ),
              child: TextField(
                controller: widget.controller,
                enabled: widget.enabled,
                textInputAction:
                    TextInputAction.send,
                onSubmitted: (_) => widget.onEnvoyer(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: widget.enabled
                      ? 'Message…'
                      : 'Envoi désactivé',
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    color: AppColors.texte2,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, valeur, _) {
              final vide =
                  valeur.text.trim().isEmpty;
              return vide
                  ? _boutonMicro()
                  : _boutonEnvoyer();
            },
          ),
        ],
      ),
    );
  }
}
