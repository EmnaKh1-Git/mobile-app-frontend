import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../app/theme.dart';
import '../../../core/services/ai_summarize_service.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../../user/services/user_service.dart';
import '../models/reclamation.dart';
import '../services/reclamation_ai_service.dart';
import '../services/reclamation_service.dart';
import '../widgets/reclamation_widgets.dart';
import 'reclamation_details_page.dart';

class AjouterReclamationPage extends StatefulWidget {
  const AjouterReclamationPage({super.key});

  @override
  State<AjouterReclamationPage> createState() => _AjouterReclamationPageState();
}

class _AjouterReclamationPageState extends State<AjouterReclamationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _sujetController = TextEditingController();
  final TextEditingController _trajetController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _autreCategorieController =
      TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ReclamationAiService _ai = ReclamationAiService();

  ReclamationType _type = ReclamationType.autre;
  String? _categoriePersonnalisee;
  XFile? _image;
  String? _audioPath;
  ReclamationAnalyse? _analyse;
  ReclamationPriorite? _prioriteIa;
  bool _enregistrement = false;
  bool _analyseEnCours = false;
  bool _summarizeEnCours = false;
  bool _soumissionEnCours = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_rafraichirCompteur);
  }

  void _rafraichirCompteur() => setState(() {});

  @override
  void dispose() {
    _descriptionController.removeListener(_rafraichirCompteur);
    _sujetController.dispose();
    _trajetController.dispose();
    _descriptionController.dispose();
    _autreCategorieController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  ReclamationPriorite get _prioriteCourante =>
      _prioriteIa ??
      ReclamationService.prioriteEstimee(
        _type,
        '${_sujetController.text} ${_descriptionController.text}',
      );

  @override
  Widget build(BuildContext context) {
    final nbMots = _descriptionController.text
        .split(RegExp(r'\s+'))
        .where((m) => m.isNotEmpty)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle réclamation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<ReclamationType>(
              key: ValueKey(_type),
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                border: OutlineInputBorder(),
              ),
              items: ReclamationType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _type = value;
                  if (value != ReclamationType.autre) {
                    _categoriePersonnalisee = null;
                    _autreCategorieController.clear();
                  }
                });
              },
            ),
            if (_type == ReclamationType.autre) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoriePersonnalisee,
                decoration: const InputDecoration(
                  labelText: 'Sous-catégorie',
                  border: OutlineInputBorder(),
                ),
                hint: const Text(
                  'Choisir une catégorie système ou en proposer une',
                ),
                items: [
                  ...ReclamationService.instance.categoriesSysteme.map(
                    (category) =>
                        DropdownMenuItem(value: category, child: Text(category)),
                  ),
                  const DropdownMenuItem(
                    value: '__nouvelle__',
                    child: Text('Proposer une nouvelle catégorie'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _categoriePersonnalisee = value;
                    if (value != '__nouvelle__') {
                      _autreCategorieController.text = value ?? '';
                    } else {
                      _autreCategorieController.clear();
                    }
                  });
                },
              ),
              if (_categoriePersonnalisee == null ||
                  _categoriePersonnalisee == '__nouvelle__') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _autreCategorieController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la catégorie à proposer',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_type == ReclamationType.autre &&
                        (value ?? '').trim().isEmpty) {
                      return 'Veuillez préciser la catégorie.';
                    }
                    return null;
                  },
                ),
              ],
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _sujetController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Objet',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) {
                  return 'Veuillez renseigner l’objet de la réclamation.';
                }
                if (v.length < 4) return 'Objet trop court.';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _trajetController,
              decoration: const InputDecoration(
                labelText: 'Trajet concerné (facultatif)',
                hintText: 'ex. Tunis → Sousse',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: 'Description détaillée (facultative si vocal)',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                helperText: '$nbMots mot${nbMots > 1 ? 's' : ''}',
              ),
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty && _audioPath == null) {
                  return 'Veuillez décrire précisément le problème.';
                }
                if (v.isNotEmpty && v.length < 15 && _audioPath == null) {
                  return 'Description trop courte (15 caractères minimum).';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _summarizeEnCours ? null : _summarizeDescription,
                icon: _summarizeEnCours
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: Text(
                  _summarizeEnCours
                      ? 'Résumé en cours…'
                      : 'Résumer / Reformuler avec l’IA',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaire,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _choisirImage,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(_image == null ? 'Photo' : 'Changer la photo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _enregistrement
                        ? _arreterEnregistrement
                        : _demarrerEnregistrement,
                    icon: Icon(
                      _enregistrement ? Icons.stop : Icons.mic_none,
                      color: _enregistrement ? Colors.red : null,
                    ),
                    label: Text(_enregistrement ? 'Arrêter' : 'Message vocal'),
                  ),
                ),
              ],
            ),
            if (_image != null) ...[
              const SizedBox(height: 10),
              Stack(
                children: [
                  ReclamationImage(path: _image!.path, height: 160),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _image = null),
                    ),
                  ),
                ],
              ),
            ],
            if (_audioPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.mic, size: 16, color: AppColors.primaire),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Message vocal enregistré',
                        style: TextStyle(fontSize: 12, color: AppColors.texte2),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _audioPath = null),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _analyseEnCours ? null : _analyserAvecIa,
              icon: _analyseEnCours
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _analyseEnCours
                    ? 'Analyse en cours...'
                    : 'Analyser avec l’IA (catégorie, priorité, conseils)',
              ),
            ),
            if (_analyse != null) ...[
              const SizedBox(height: 12),
              _CarteAnalyse(
                analyse: _analyse!,
                onAppliquer: _appliquerAnalyse,
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.champFond,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.texte2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Priorité estimée : ${_prioriteCourante.label} — '
                      'réponse attendue sous ${_prioriteCourante.sla.inHours} h.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  PrioriteBadge(priorite: _prioriteCourante, compact: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _soumissionEnCours ? null : _soumettre,
              icon: _soumissionEnCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _soumissionEnCours
                    ? 'Envoi en cours...'
                    : 'Soumettre la réclamation',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Médias
  // ---------------------------------------------------------------------

  Future<void> _choisirImage() async {
    final source = await choisirSourceImage(context);
    if (source == null) return;
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (image != null && mounted) setState(() => _image = image);
  }

  Future<void> _demarrerEnregistrement() async {
    if (!await _audioRecorder.hasPermission()) {
      _afficherMessage('L’autorisation du microphone est nécessaire.');
      return;
    }
    final path =
        '${Directory.systemTemp.path}/reclamation_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (mounted) setState(() => _enregistrement = true);
  }

  Future<void> _arreterEnregistrement() async {
    final path = await _audioRecorder.stop();
    if (mounted) {
      setState(() {
        _enregistrement = false;
        _audioPath = path;
      });
    }
  }

  // ---------------------------------------------------------------------
  // IA
  // ---------------------------------------------------------------------

  Future<void> _summarizeDescription() async {
    final texte = _descriptionController.text.trim();
    if (texte.isEmpty) {
      _afficherMessage('Rédigez d’abord une description à résumer.');
      return;
    }

    setState(() => _summarizeEnCours = true);
    try {
      final resultat = await AiSummarizeService.instance.resumer(
        texte,
        sujet: _sujetController.text,
      );
      if (!mounted || resultat == null) return;

      if (resultat.texte.trim() == texte ||
          (resultat.source == SourceResume.local && resultat.dejaConcis)) {
        _afficherMessage(
          resultat.avertissement == null
              ? 'Votre description est déjà concise.'
              : 'Votre description est déjà concise. '
                    '(${resultat.avertissement})',
        );
        return;
      }

      final ancien = _descriptionController.text;
      _descriptionController.text = resultat.texte;
      _descriptionController.selection = TextSelection.collapsed(
        offset: resultat.texte.length,
      );

      final message = resultat.source == SourceResume.deepseek
          ? '✨ Description résumée par l’IA DeepSeek.'
          : 'Résumé local appliqué — ${resultat.avertissement ?? 'IA indisponible'}.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: resultat.source == SourceResume.deepseek
                ? AppColors.primaire
                : AppColors.alerte,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Annuler',
              textColor: Colors.white,
              onPressed: () => _descriptionController.text = ancien,
            ),
          ),
        );
    } catch (e) {
      _afficherMessage('Erreur de résumé : $e');
    } finally {
      if (mounted) setState(() => _summarizeEnCours = false);
    }
  }

  Future<void> _analyserAvecIa() async {
    if (_sujetController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      _afficherMessage('Renseignez l’objet et la description avant l’analyse.');
      return;
    }
    setState(() => _analyseEnCours = true);
    try {
      final analyse = await _ai.analyser(
        sujet: _sujetController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _analyse = analyse;
        _prioriteIa = analyse.priorite;
      });
      if (analyse.locale) {
        _afficherMessage(
          'Analyse locale (clé DeepSeek absente) — résultat indicatif.',
        );
      }
    } on ReclamationAiException catch (error) {
      _afficherMessage(error.message);
    } catch (error) {
      _afficherMessage('Impossible de contacter l’assistance IA : $error');
    } finally {
      if (mounted) setState(() => _analyseEnCours = false);
    }
  }

  void _appliquerAnalyse() {
    final a = _analyse;
    if (a == null) return;
    setState(() {
      _type = a.type;
      if (a.type != ReclamationType.autre) {
        _categoriePersonnalisee = null;
        _autreCategorieController.clear();
      }
      if (_sujetController.text.trim().length < 4 ||
          a.objetSuggere.isNotEmpty) {
        _sujetController.text = a.objetSuggere.isEmpty
            ? _sujetController.text
            : a.objetSuggere;
      }
      _prioriteIa = a.priorite;
    });
    _afficherMessage('Suggestions de l’IA appliquées.');
  }

  // ---------------------------------------------------------------------
  // Soumission
  // ---------------------------------------------------------------------

  void _afficherMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _soumettre() async {
    if (!_formKey.currentState!.validate()) return;
    if (_enregistrement) await _arreterEnregistrement();

    final user = UserService.instance.currentUser;
    final service = ReclamationService.instance;

    // Règle 1 : limite anti-spam
    try {
      service.verifierLimite(user?.id);
    } on ReclamationRegleException catch (e) {
      _afficherMessage(e.message);
      return;
    }

    // Règle 2 : détection de doublons
    final doublons = service.trouverDoublons(
      sujet: _sujetController.text,
      description: _descriptionController.text,
      auteurId: user?.id,
    );
    if (doublons.isNotEmpty) {
      final continuer = await _confirmerDoublon(doublons.first);
      if (continuer != true) return;
    }

    setState(() => _soumissionEnCours = true);

    var imagePath = _image?.path;
    if (imagePath != null) {
      imagePath =
          await SupabaseStorageService.instance.uploadImage(imagePath) ??
          imagePath;
    }
    var audioPath = _audioPath;
    if (audioPath != null) {
      audioPath =
          await SupabaseStorageService.instance.uploadAudio(audioPath) ??
          audioPath;
    }

    final nouvelleReclamation = Reclamation(
      id: DateTime.now().millisecondsSinceEpoch,
      type: _type,
      sujet: _sujetController.text.trim(),
      description: _descriptionController.text.trim(),
      trajet: _trajetController.text.trim().isEmpty
          ? 'Trajet non précisé'
          : _trajetController.text.trim(),
      date: DateTime.now(),
      status: ReclamationStatus.enAttente,
      autreCategorie: _type == ReclamationType.autre
          ? _autreCategorieController.text.trim()
          : null,
      imagePath: imagePath,
      audioPath: audioPath,
      aiConseil: _analyse?.texteConseil,
      priorite: _prioriteCourante,
      sentiment: _analyse?.sentiment,
      auteurId: user?.id,
      auteurNom: user?.nomComplet,
    );

    service.ajouter(nouvelleReclamation);
    if (!mounted) return;
    setState(() => _soumissionEnCours = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Réclamation envoyée. Réponse attendue sous '
          '${nouvelleReclamation.priorite.sla.inHours} h.',
        ),
      ),
    );
    Navigator.pop(context);
  }

  Future<bool?> _confirmerDoublon(Reclamation existante) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.content_copy_rounded),
        title: const Text('Réclamation similaire'),
        content: Text(
          'Une réclamation ouverte semble déjà traiter ce problème :\n\n'
          '« ${existante.sujet} » (${existante.status.label}).\n\n'
          'Vous pouvez y ajouter un message plutôt que d’en créer une nouvelle.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ReclamationDetailsPage(reclamation: existante),
                ),
              );
            },
            child: const Text('Voir l’existante'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Créer quand même'),
          ),
        ],
      ),
    );
  }
}

/// Feuille de choix galerie / appareil photo (réutilisée par le détail).
Future<ImageSource?> choisirSourceImage(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choisir dans la galerie'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
}

class _CarteAnalyse extends StatelessWidget {
  final ReclamationAnalyse analyse;
  final VoidCallback onAppliquer;

  const _CarteAnalyse({required this.analyse, required this.onAppliquer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaireDoux,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primaire),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  analyse.locale ? 'Analyse locale' : 'Analyse DeepSeek',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              PrioriteBadge(priorite: analyse.priorite, compact: true),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('Catégorie : ${analyse.type.label}'),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('Ton : ${analyse.sentiment}'),
              ),
            ],
          ),
          if (analyse.conseil.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(analyse.conseil),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAppliquer,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Appliquer les suggestions'),
            ),
          ),
        ],
      ),
    );
  }
}
