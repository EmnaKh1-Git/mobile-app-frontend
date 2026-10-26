import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioRecorder _recorder = AudioRecorder();
  String? _cheminEnCours;
  String? _dernierCheminEnregistre;

  final AudioPlayer _player = AudioPlayer();
  String? _messageIdEnCours;

  String? get dernierCheminEnregistre => _dernierCheminEnregistre;

  void setDernierCheminEnregistre(String? chemin) {
    _dernierCheminEnregistre = chemin;
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<bool> demanderPermission() async {
    final statut = await Permission.microphone.request();
    return statut.isGranted;
  }

  Future<void> demarrerEnregistrement() async {
    final documents = await getApplicationDocumentsDirectory();
    final dossier = Directory('${documents.path}/vocaux');
    if (!await dossier.exists()) {
      await dossier.create(recursive: true);
    }

    final nomFichier = 'vocal_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _cheminEnCours = '${dossier.path}/$nomFichier';

    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    );

    await _recorder.start(config, path: _cheminEnCours!);
  }

  Future<String?> arreterEnregistrement() async {
    final chemin = await _recorder.stop();
    final resultat = chemin ?? _cheminEnCours;
    _cheminEnCours = null;
    return resultat;
  }

  Future<void> annulerEnregistrement() async {
    await _recorder.stop();
    if (_cheminEnCours != null) {
      final fichier = File(_cheminEnCours!);
      if (await fichier.exists()) {
        await fichier.delete();
      }
      _cheminEnCours = null;
    }
  }

  Future<void> jouer(String messageId, String? cheminAudio) async {
    if (cheminAudio == null || cheminAudio.isEmpty) {
      throw Exception('Vocal indisponible');
    }
    final fichier = File(cheminAudio);
    if (!await fichier.exists()) {
      throw Exception('Vocal indisponible');
    }

    if (_messageIdEnCours != null && _messageIdEnCours != messageId) {
      await _player.stop();
    }

    _messageIdEnCours = messageId;

    try {
      await _player.setAudioSource(AudioSource.file(cheminAudio));
      await _player.setSpeed(_player.speed);
      await _player.play();
    } catch (e) {
      throw Exception('Vocal indisponible');
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> reprendre() async {
    await _player.play();
  }

  Future<void> changerVitesse(double vitesse) async {
    await _player.setSpeed(vitesse);
  }

  Future<void> arreter() async {
    await _player.stop();
    _messageIdEnCours = null;
  }

  String? get messageIdEnCours => _messageIdEnCours;

  Future<void> dispose() async {
    await _player.dispose();
    await _recorder.dispose();
  }
}
