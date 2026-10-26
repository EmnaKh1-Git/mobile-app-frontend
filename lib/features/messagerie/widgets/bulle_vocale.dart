import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme.dart';
import '../../../core/utils/helpers.dart';

import '../models/message.dart';
import '../services/audio_service.dart';
import '../services/messagerie_service.dart';

// ============================================================
// BULLE DE MESSAGE VOCAL
// ============================================================

class BulleVocale extends StatefulWidget {
  final Message message;

  /// Affiche le nom de l'expéditeur au-dessus de la bulle
  /// (conversations de groupe uniquement).
  final bool afficherNom;

  /// Appui long (ex. signaler un message).
  final VoidCallback? onLongPress;

  const BulleVocale({
    super.key,
    required this.message,
    this.afficherNom = false,
    this.onLongPress,
  });

  @override
  State<BulleVocale> createState() => _BulleVocaleState();
}

class _BulleVocaleState extends State<BulleVocale> {
  late final List<double> _barres;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  bool _lecture = false;
  double _vitesse = 1;
  double _progression = 0;
  Duration _position = Duration.zero;
  Duration _dureeReelle = Duration.zero;

  int get _duree => widget.message.dureeSecondes ?? 0;

  @override
  void initState() {
    super.initState();

    // Hauteurs stables, calculées depuis l'identifiant du message.
    final aleatoire = Random(widget.message.id.hashCode);
    _barres = List<double>.generate(
      24,
      (_) => 0.3 + aleatoire.nextDouble() * 0.7,
    );

    MessagerieService.instance.vocalEnLecture.addListener(
      _surChangementLecture,
    );

    _posSub = AudioService.instance.positionStream.listen((pos) {
      if (AudioService.instance.messageIdEnCours !=
          widget.message.id) {
        return;
      }
      if (!mounted) return;
      _position = pos;
      final total = _dureeReelle.inMilliseconds;
      if (total > 0) {
        setState(() {
          _progression = (_position.inMilliseconds / total).clamp(0.0, 1.0);
        });
      }
    });

    _stateSub = AudioService.instance.playerStateStream.listen((state) {
      if (AudioService.instance.messageIdEnCours !=
          widget.message.id) {
        return;
      }
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        _revenirInitial();
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    MessagerieService.instance.vocalEnLecture.removeListener(
      _surChangementLecture,
    );
    if (_lecture || AudioService.instance.messageIdEnCours == widget.message.id) {
      AudioService.instance.arreter();
      MessagerieService.instance.arreterLectureVocal(
        widget.message.id,
      );
    }
    super.dispose();
  }

  void _revenirInitial() {
    if (!mounted) return;
    setState(() {
      _lecture = false;
      _progression = 0;
      _position = Duration.zero;
    });
    MessagerieService.instance.arreterLectureVocal(widget.message.id);
    AudioService.instance.arreter();
  }

  // ---------------------------------------------------------
  // LECTURE / PAUSE
  // ---------------------------------------------------------

  void _surChangementLecture() {
    final actif =
        MessagerieService.instance.vocalEnLectureId;
    if (actif != widget.message.id && _lecture) {
      AudioService.instance.pause();
      setState(() {
        _lecture = false;
      });
    }
  }

  void _basculerLecture() {
    if (_lecture) {
      _mettreEnPause();
    } else {
      _demarrerLecture();
    }
  }

  Future<void> _demarrerLecture() async {
    if (_progression >= 1) {
      _progression = 0;
      _position = Duration.zero;
      await AudioService.instance.arreter();
    }

    MessagerieService.instance.demarrerLectureVocal(
      widget.message.id,
    );

    setState(() {
      _lecture = true;
    });

    if (!widget.message.estMien &&
        !widget.message.ecoute) {
      MessagerieService.instance.marquerEcoute(
        widget.message.id,
      );
    }

    try {
      await AudioService.instance.jouer(
        widget.message.id,
        widget.message.cheminAudio,
      );
      final d = await AudioService.instance.playerStateStream.first.then((_) async {
        try {
          return await AudioService.instance.durationStream.first;
        } catch (_) {
          return null;
        }
      });
      if (d != null && mounted) {
        _dureeReelle = d;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lecture = false;
      });
      MessagerieService.instance.arreterLectureVocal(widget.message.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vocal indisponible')),
      );
      return;
    }
  }

  Future<void> _mettreEnPause() async {
    await AudioService.instance.pause();
    setState(() {
      _lecture = false;
    });
    MessagerieService.instance.arreterLectureVocal(
      widget.message.id,
    );
  }

  Future<void> _changerVitesse() async {
    double nouvelle;
    if (_vitesse == 1) {
      nouvelle = 1.5;
    } else if (_vitesse == 1.5) {
      nouvelle = 2;
    } else {
      nouvelle = 1;
    }
    setState(() {
      _vitesse = nouvelle;
    });
    try {
      await AudioService.instance.changerVitesse(nouvelle);
    } catch (_) {}
  }

  String get _vitesseLabel {
    if (_vitesse == 1.5) return '1,5x';
    if (_vitesse == 2) return '2x';
    return '1x';
  }

  String get _dureeLabel {
    final total = _dureeReelle.inSeconds > 0
        ? _dureeReelle.inSeconds
        : _duree;
    if (!_lecture && _progression == 0) {
      return formaterDureeVocale(total);
    }
    final actuelle = (_progression * total).floor();
    final clamped = actuelle > total ? total : actuelle;
    return '${formaterDureeVocale(clamped)} / '
        '${formaterDureeVocale(total)}';
  }

  // ---------------------------------------------------------
  // ÉLÉMENTS VISUELS
  // ---------------------------------------------------------

  Widget _boutonLecture(bool mien) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Material(
        color: mien
            ? Colors.white24
            : AppColors.primaireDoux,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _basculerLecture,
          child: Icon(
            _lecture ? Icons.pause : Icons.play_arrow,
            size: 22,
            color: mien
                ? Colors.white
                : AppColors.primaire,
          ),
        ),
      ),
    );
  }

  Widget _barre(int index, bool mien) {
    final jouee =
        (index + 1) / _barres.length <= _progression;
    final couleur = mien
        ? (jouee ? Colors.white : Colors.white38)
        : (jouee
            ? AppColors.primaire
            : AppColors.primaireDoux);

    return Container(
      width: 3,
      height: 8 + _barres[index] * 18,
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _boutonVitesse(bool mien) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _changerVitesse,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: mien
              ? Colors.white24
              : AppColors.primaireDoux,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _vitesseLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: mien
                ? Colors.white
                : AppColors.primaire,
          ),
        ),
      ),
    );
  }

  Widget _pastilleNonEcoute() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Non écouté',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.supprimePourTous) {
      final estGroupe = widget.afficherNom || !widget.message.estMien;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.bordure,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              estGroupe && !widget.message.estMien
                  ? '🚫 ${widget.message.expediteurNom} : Ce message a été supprimé'
                  : '🚫 Ce message a été supprimé',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.texte2,
              ),
            ),
          ),
        ),
      );
    }
    final mien = widget.message.estMien;
    final nomVisible = widget.afficherNom && !mien;
    final nonEcoute = !mien && !widget.message.ecoute;
    final texteSecondaire =
        mien ? Colors.white70 : AppColors.texte2;

    return Row(
      mainAxisAlignment: mien
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(
          child: GestureDetector(
            onLongPress: widget.onLongPress,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 320,
              ),
              padding: const EdgeInsets.fromLTRB(
                10,
                8,
                12,
                6,
              ),
              decoration: BoxDecoration(
                color: mien
                    ? AppColors.primaire
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(
                    mien ? 18 : 4,
                  ),
                  bottomRight: Radius.circular(
                    mien ? 4 : 18,
                  ),
                ),
                border: mien
                    ? null
                    : Border.all(
                        color: AppColors.bordure,
                      ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (nomVisible) ...[
                    Text(
                      widget.message.expediteurNom,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaire,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _boutonLecture(mien),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 26,
                              child: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  for (var i = 0;
                                      i < _barres.length;
                                      i++) ...[
                                    if (i > 0)
                                      const SizedBox(
                                        width: 2,
                                      ),
                                    _barre(i, mien),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Text(
                                  _dureeLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        texteSecondaire,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _boutonVitesse(mien),
                                if (nonEcoute) ...[
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  _pastilleNonEcoute(),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fHeure(
                          widget.message.dateEnvoi,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: texteSecondaire,
                        ),
                      ),
                      if (mien) ...[
                        const SizedBox(width: 5),
                        Text(
                          widget.message.statut ==
                                  StatutMessage.lu
                              ? '✓✓'
                              : '✓',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      if (widget.message.estSignale) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.flag_outlined,
                          size: 12,
                          color: mien
                              ? Colors.white70
                              : AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Signalé',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: mien
                                ? Colors.white70
                                : AppColors.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
