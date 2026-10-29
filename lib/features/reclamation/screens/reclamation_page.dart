import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../app/theme.dart';
import '../models/reclamation.dart';
import '../services/reclamation_service.dart';
import '../services/reclamation_ai_service.dart';
import '../../user/services/user_service.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../../../core/services/ai_summarize_service.dart';

class ReclamationPage extends StatelessWidget {
  const ReclamationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réclamations'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AjouterReclamationPage(),
                ),
              );
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Nouvelle réclamation',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: ReclamationService.instance,
        builder: (context, _) {
          final reclamations = ReclamationService.instance.reclamations;

          if (reclamations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune réclamation enregistrée.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.texte2),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reclamations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final reclamation = reclamations[index];

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReclamationDetailsPage(reclamation: reclamation),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.bordure),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaireDoux,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.report_problem_outlined,
                              color: AppColors.primaire,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reclamation.sujet,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reclamation.typeLabel,
                                  style: const TextStyle(
                                    color: AppColors.texte2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusChip(status: reclamation.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        reclamation.trajet,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaire,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat(
                          'dd MMM yyyy',
                          'fr_FR',
                        ).format(reclamation.date),
                        style: const TextStyle(
                          color: AppColors.texte2,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AjouterReclamationPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle'),
      ),
    );
  }
}

class _AttachedImage extends StatelessWidget {
  final String path;

  const _AttachedImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final isNetworkImage =
        path.startsWith('http://') || path.startsWith('https://');
    final image = isNetworkImage
        ? Image.network(
            path,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 220,
                color: AppColors.champFond,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              height: 220,
              color: AppColors.champFond,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
            ),
          )
        : Image.file(
            File(path),
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          );

    return ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
  }
}

class ReclamationDetailsPage extends StatefulWidget {
  final Reclamation reclamation;

  const ReclamationDetailsPage({super.key, required this.reclamation});

  @override
  State<ReclamationDetailsPage> createState() => _ReclamationDetailsPageState();
}

class _ReclamationDetailsPageState extends State<ReclamationDetailsPage> {
  static const _audioChannel = MethodChannel('covoiturage/audio');
  static const _audioEvents = EventChannel('covoiturage/audio_events');
  late ReclamationStatus _status;
  final TextEditingController _responseController = TextEditingController();
  StreamSubscription<dynamic>? _audioEventsSubscription;
  String? _currentlyPlayingPath;

  // Enregistrement vocal réponse admin
  final AudioRecorder _responseRecorder = AudioRecorder();
  bool _enregistrementReponse = false;
  String? _reponseAudioPath;
  bool _uploadVocalEnCours = false;

  @override
  void initState() {
    super.initState();
    _status = widget.reclamation.status;
    _audioEventsSubscription = _audioEvents.receiveBroadcastStream().listen((
      event,
    ) {
      if (event == 'completed' && mounted) {
        setState(() => _currentlyPlayingPath = null);
      }
    });
  }

  @override
  void dispose() {
    _audioChannel.invokeMethod<void>('stop');
    _audioEventsSubscription?.cancel();
    _responseController.dispose();
    _responseRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la réclamation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.reclamation.sujet,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Type', value: widget.reclamation.typeLabel),
                  _InfoRow(label: 'Trajet', value: widget.reclamation.trajet),
                  _InfoRow(
                    label: 'Date',
                    value: DateFormat(
                      'dd MMM yyyy à HH:mm',
                      'fr_FR',
                    ).format(widget.reclamation.date),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Statut',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (UserService.instance.currentUser?.isAdmin ?? false)
                    DropdownButtonFormField<ReclamationStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: ReclamationStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(_statusLabel(status)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                        ReclamationService.instance.mettreAJourStatut(
                          widget.reclamation.id,
                          value,
                        );
                      },
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: Text(_statusLabel(_status)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Description',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bordure),
            ),
            child: Text(
              widget.reclamation.description.trim().isEmpty
                  ? 'Description fournie par message vocal.'
                  : widget.reclamation.description,
              style: const TextStyle(height: 1.5),
            ),
          ),

          // Réponses existantes de l'administration
          if (widget.reclamation.responses.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Réponses de l’administration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...widget.reclamation.responses.map(
              (response) => Card(
                color: AppColors.primaireDoux,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: AppColors.primaire,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  response.message,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(
                                    'dd/MM/yyyy à HH:mm',
                                    'fr_FR',
                                  ).format(response.date),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.texte2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (response.audioPath != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaire.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _currentlyPlayingPath == response.audioPath
                                      ? Icons.stop_circle_rounded
                                      : Icons.play_circle_fill_rounded,
                                  color: AppColors.primaire,
                                  size: 32,
                                ),
                                onPressed: () => _toggleAudio(response.audioPath!),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentlyPlayingPath == response.audioPath
                                      ? 'Lecture du vocal...'
                                      : 'Écouter la réponse vocale',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaire,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.graphic_eq_rounded,
                                color: AppColors.primaire,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Formulaire de réponse pour l'administrateur
          if (UserService.instance.currentUser?.isAdmin ?? false) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaire.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.reply_rounded, color: AppColors.primaire),
                      SizedBox(width: 8),
                      Text(
                        'Répondre à l’étudiant (Admin)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaire,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Saisie de texte
                  TextField(
                    controller: _responseController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Rédigez votre réponse ou utilisez le vocal...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Section enregistrement vocal
                  if (_reponseAudioPath == null)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _enregistrementReponse
                                ? _arreterReponseVocale
                                : _demarrerReponseVocale,
                            icon: Icon(
                              _enregistrementReponse
                                  ? Icons.stop_circle_rounded
                                  : Icons.mic_rounded,
                              color: _enregistrementReponse
                                  ? Colors.red
                                  : AppColors.primaire,
                            ),
                            label: Text(
                              _enregistrementReponse
                                  ? 'Arrêter l’enregistrement'
                                  : 'Répondre par vocal 🎤',
                              style: TextStyle(
                                color: _enregistrementReponse
                                    ? Colors.red
                                    : AppColors.primaire,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: _enregistrementReponse
                                    ? Colors.red
                                    : AppColors.primaire,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaireDoux,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaire),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _currentlyPlayingPath == _reponseAudioPath
                                  ? Icons.stop_circle_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: AppColors.primaire,
                              size: 28,
                            ),
                            onPressed: () => _toggleAudio(_reponseAudioPath!),
                            tooltip: 'Écouter l’aperçu',
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Vocal enregistré prêt à envoyer',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              if (_currentlyPlayingPath == _reponseAudioPath) {
                                _audioChannel.invokeMethod<void>('stop');
                                setState(() => _currentlyPlayingPath = null);
                              }
                              setState(() => _reponseAudioPath = null);
                            },
                            tooltip: 'Supprimer le vocal',
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Bouton d'envoi
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _uploadVocalEnCours ? null : _envoyerReponseAdmin,
                      icon: _uploadVocalEnCours
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _uploadVocalEnCours
                          ? 'Envoi en cours...'
                          : (_reponseAudioPath != null && _responseController.text.trim().isEmpty)
                              ? 'Envoyer la réponse vocale'
                              : 'Envoyer la réponse',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Pièces jointes initiales de l'étudiant
          if (widget.reclamation.imagePath != null ||
              widget.reclamation.audioPath != null ||
              widget.reclamation.aiConseil != null) ...[
            const SizedBox(height: 20),
            const Text(
              'Pièces jointes & Analyse',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (widget.reclamation.imagePath != null)
              _AttachedImage(path: widget.reclamation.imagePath!),
            if (widget.reclamation.audioPath != null) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mic_none, color: AppColors.primaire),
                title: const Text('Message vocal étudiant joint'),
                subtitle: Text(
                  _currentlyPlayingPath == widget.reclamation.audioPath
                      ? 'Lecture en cours...'
                      : 'Appuyer pour écouter',
                ),
                trailing: IconButton(
                  icon: Icon(
                    _currentlyPlayingPath == widget.reclamation.audioPath
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                    color: AppColors.primaire,
                    size: 30,
                  ),
                  onPressed: () => _toggleAudio(widget.reclamation.audioPath!),
                ),
              ),
            ],
            if (widget.reclamation.aiConseil != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Conseil de l’assistance IA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaireDoux,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(widget.reclamation.aiConseil!),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _demarrerReponseVocale() async {
    if (!await _responseRecorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L’accès au microphone est nécessaire.')),
      );
      return;
    }
    final path =
        '${Directory.systemTemp.path}/admin_reponse_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _responseRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (mounted) setState(() => _enregistrementReponse = true);
  }

  Future<void> _arreterReponseVocale() async {
    final path = await _responseRecorder.stop();
    if (mounted) {
      setState(() {
        _enregistrementReponse = false;
        _reponseAudioPath = path;
      });
    }
  }

  Future<void> _envoyerReponseAdmin() async {
    final messageText = _responseController.text.trim();
    if (messageText.isEmpty && _reponseAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saisissez un message ou enregistrez un vocal.'),
        ),
      );
      return;
    }

    setState(() => _uploadVocalEnCours = true);

    String? audioUrl;
    if (_reponseAudioPath != null) {
      // Upload vocal vers Supabase Storage
      audioUrl = await SupabaseStorageService.instance.uploadAudio(_reponseAudioPath!);
      audioUrl ??= _reponseAudioPath; // fallback local
    }

    final messageFinal = messageText.isNotEmpty
        ? messageText
        : '🎤 [Réponse vocale de l’administration]';

    ReclamationService.instance.ajouterReponse(
      widget.reclamation.id,
      messageFinal,
      audioPath: audioUrl,
    );

    if (mounted) {
      _responseController.clear();
      setState(() {
        _uploadVocalEnCours = false;
        _reponseAudioPath = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réponse envoyée avec succès.')),
      );
    }
  }

  Future<void> _toggleAudio(String path) async {
    try {
      if (_currentlyPlayingPath == path) {
        await _audioChannel.invokeMethod<void>('stop');
        if (mounted) setState(() => _currentlyPlayingPath = null);
      } else {
        await _audioChannel.invokeMethod<void>('stop');
        await _audioChannel.invokeMethod<void>('play', {'path': path});
        if (mounted) setState(() => _currentlyPlayingPath = path);
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de lire le vocal : $error')),
      );
    }
  }

  String _statusLabel(ReclamationStatus status) {
    switch (status) {
      case ReclamationStatus.enAttente:
        return 'En attente';
      case ReclamationStatus.enCours:
        return 'En cours';
      case ReclamationStatus.resolue:
        return 'Résolue';
    }
  }
}

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

  ReclamationType _type = ReclamationType.autre;
  String? _categoriePersonnalisee;
  XFile? _image;
  String? _audioPath;
  String? _aiConseil;
  bool _enregistrement = false;
  bool _analyseEnCours = false;
  bool _summarizeEnCours = false;
  bool _soumissionEnCours = false;

  @override
  void dispose() {
    _sujetController.dispose();
    _trajetController.dispose();
    _descriptionController.dispose();
    _autreCategorieController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle réclamation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<ReclamationType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                border: OutlineInputBorder(),
              ),
              items: ReclamationType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(_typeLabel(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _type = value;
                    if (value != ReclamationType.autre) {
                      _categoriePersonnalisee = null;
                      _autreCategorieController.clear();
                    }
                  });
                }
              },
            ),
            if (_type == ReclamationType.autre) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoriePersonnalisee,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                hint: const Text(
                  'Choisir une catégorie système ou en proposer une',
                ),
                items: [
                  ...ReclamationService.instance.categoriesSysteme.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
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
              decoration: const InputDecoration(
                labelText: 'Objet',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Veuillez renseigner l’objet de la réclamation.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _trajetController,
              decoration: const InputDecoration(
                labelText: 'Trajet concerné (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Champ de description avec icône Reformuler / Résumer
            TextFormField(
              controller: _descriptionController,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'Description détaillée (facultative si vocal)',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: _summarizeEnCours
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Reformuler / Résumer avec l’IA',
                          icon: const Icon(
                            Icons.auto_fix_high_rounded,
                            color: AppColors.primaire,
                            size: 26,
                          ),
                          onPressed: _summarizeDescription,
                        ),
                ),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty && _audioPath == null) {
                  return 'Veuillez décrire précisément le problème.';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _summarizeEnCours ? null : _summarizeDescription,
                icon: const Icon(Icons.summarize_outlined, size: 18),
                label: const Text('Résumer / Reformuler avec l’IA'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaire,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _choisirImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _image == null ? 'Ajouter une image' : 'Image ajoutée ✓',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _enregistrement
                        ? _arreterEnregistrement
                        : _demarrerEnregistrement,
                    icon: Icon(_enregistrement ? Icons.stop : Icons.mic_none),
                    label: Text(_enregistrement ? 'Arrêter' : 'Message vocal'),
                  ),
                ),
              ],
            ),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 16, color: AppColors.primaire),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Image prête (upload Supabase Storage) : ${_image!.name}',
                        style: const TextStyle(fontSize: 12, color: AppColors.texte2),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _image = null),
                    ),
                  ],
                ),
              ),
            if (_audioPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.mic, size: 16, color: AppColors.primaire),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Vocal enregistré (upload Supabase Storage)',
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
                    : 'Obtenir l’aide de l’IA',
              ),
            ),
            if (_aiConseil != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaireDoux,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_aiConseil!),
              ),
            ],
            const SizedBox(height: 24),
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
                    ? 'Envoi en cours (Supabase Storage)...'
                    : 'Soumettre la réclamation',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choisirImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null && mounted) {
      setState(() => _image = image);
    }
  }

  Future<void> _demarrerEnregistrement() async {
    if (!await _audioRecorder.hasPermission()) {
      _afficherErreur('L’autorisation du microphone est nécessaire.');
      return;
    }
    final path =
        '${Directory.systemTemp.path}/reclamation_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (mounted) {
      setState(() => _enregistrement = true);
    }
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

  Future<void> _summarizeDescription() async {
    final texte = _descriptionController.text.trim();
    if (texte.isEmpty) {
      _afficherErreur('Rédigez d’abord une description à reformuler.');
      return;
    }

    setState(() => _summarizeEnCours = true);
    try {
      final reformule = await AiSummarizeService.instance.reformuler(texte);
      if (reformule != null && reformule.isNotEmpty && mounted) {
        _descriptionController.text = reformule;
        _descriptionController.selection = TextSelection.fromPosition(
          TextPosition(offset: reformule.length),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Description reformulée et résumée avec l’IA !'),
            backgroundColor: AppColors.primaire,
          ),
        );
      }
    } catch (e) {
      _afficherErreur('Erreur de reformulation : $e');
    } finally {
      if (mounted) setState(() => _summarizeEnCours = false);
    }
  }

  Future<void> _analyserAvecIa() async {
    if (_sujetController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      _afficherErreur('Renseignez l’objet et la description avant l’analyse.');
      return;
    }
    setState(() => _analyseEnCours = true);
    try {
      final conseil = await ReclamationAiService().analyser(
        sujet: _sujetController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      if (mounted) {
        setState(() => _aiConseil = conseil);
      }
    } on ReclamationAiException catch (error) {
      _afficherErreur(error.message);
    } catch (error) {
      _afficherErreur('Impossible de contacter l’assistance IA : $error');
    } finally {
      if (mounted) {
        setState(() => _analyseEnCours = false);
      }
    }
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _soumettre() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _soumissionEnCours = true);

    // 1. Upload de l'image sur Supabase Storage
    var imagePath = _image?.path;
    if (imagePath != null) {
      final supabaseUrl =
          await SupabaseStorageService.instance.uploadImage(imagePath);
      if (supabaseUrl != null) {
        imagePath = supabaseUrl;
      }
    }

    // 2. Upload de l'audio sur Supabase Storage
    var audioPath = _audioPath;
    if (audioPath != null) {
      final supabaseUrl =
          await SupabaseStorageService.instance.uploadAudio(audioPath);
      if (supabaseUrl != null) {
        audioPath = supabaseUrl;
      }
    }

    final nouvelleReclamation = Reclamation(
      id: DateTime.now().millisecondsSinceEpoch,
      type: _type,
      sujet: _sujetController.text.trim(),
      description: _descriptionController.text.trim(),
      trajet: (_trajetController.text.trim().isEmpty)
          ? 'Trajet non précisé'
          : _trajetController.text.trim(),
      date: DateTime.now(),
      status: ReclamationStatus.enAttente,
      autreCategorie: _type == ReclamationType.autre
          ? _autreCategorieController.text.trim()
          : null,
      imagePath: imagePath,
      audioPath: audioPath,
      aiConseil: _aiConseil,
    );

    ReclamationService.instance.ajouter(nouvelleReclamation);
    if (mounted) {
      setState(() => _soumissionEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réclamation envoyée avec succès.')),
      );
      Navigator.pop(context);
    }
  }

  String _typeLabel(ReclamationType type) {
    switch (type) {
      case ReclamationType.retard:
        return 'Retard';
      case ReclamationType.conducteur:
        return 'Conducteur';
      case ReclamationType.vehicule:
        return 'Véhicule';
      case ReclamationType.paiement:
        return 'Paiement';
      case ReclamationType.autre:
        return 'Autre';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final ReclamationStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case ReclamationStatus.enAttente:
        backgroundColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF8A6D1C);
        break;
      case ReclamationStatus.enCours:
        backgroundColor = const Color(0xFFE6F4FF);
        textColor = const Color(0xFF0057B8);
        break;
      case ReclamationStatus.resolue:
        backgroundColor = const Color(0xFFE8F7E9);
        textColor = const Color(0xFF1E7E34);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  String get statusLabel {
    switch (status) {
      case ReclamationStatus.enAttente:
        return 'En attente';
      case ReclamationStatus.enCours:
        return 'En cours';
      case ReclamationStatus.resolue:
        return 'Résolue';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label :',
              style: const TextStyle(color: AppColors.texte2),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
