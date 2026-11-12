import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';

import '../../../app/theme.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../../user/services/user_service.dart';
import '../models/reclamation.dart';
import '../services/reclamation_ai_service.dart';
import '../services/reclamation_service.dart';
import '../widgets/reclamation_widgets.dart';
import 'ajouter_reclamation_page.dart' show choisirSourceImage;

class ReclamationDetailsPage extends StatefulWidget {
  final Reclamation reclamation;

  const ReclamationDetailsPage({super.key, required this.reclamation});

  @override
  State<ReclamationDetailsPage> createState() => _ReclamationDetailsPageState();
}

class _ReclamationDetailsPageState extends State<ReclamationDetailsPage> {
  static const _audioChannel = MethodChannel('covoiturage/audio');
  static const _audioEvents = EventChannel('covoiturage/audio_events');

  final TextEditingController _responseController = TextEditingController();
  final AudioRecorder _responseRecorder = AudioRecorder();
  final ReclamationAiService _ai = ReclamationAiService();

  StreamSubscription<dynamic>? _audioEventsSubscription;
  String? _currentlyPlayingPath;
  bool _enregistrementReponse = false;
  String? _reponseAudioPath;
  XFile? _reponseImage;
  bool _envoiEnCours = false;
  bool _suggestionEnCours = false;

  bool get _isAdmin => UserService.instance.currentUser?.isAdmin ?? false;
  String? get _nomUtilisateur => UserService.instance.currentUser?.nomComplet;

  Reclamation get _r =>
      ReclamationService.instance.parId(widget.reclamation.id) ??
      widget.reclamation;

  @override
  void initState() {
    super.initState();
    _audioEventsSubscription = _audioEvents.receiveBroadcastStream().listen(
      (event) {
        if (event == 'completed' && mounted) {
          setState(() => _currentlyPlayingPath = null);
        }
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _audioChannel.invokeMethod<void>('stop').catchError((_) {});
    _audioEventsSubscription?.cancel();
    _responseController.dispose();
    _responseRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ReclamationService.instance,
      builder: (context, _) {
        final r = _r;
        final peutEcrire = _isAdmin || !r.status.estCloturee;
        return Scaffold(
          appBar: AppBar(title: const Text('Détail de la réclamation')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _entete(r),
              const SizedBox(height: 16),
              _titreSection('Description'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: _boite(),
                child: Text(
                  r.description.trim().isEmpty
                      ? 'Description fournie par message vocal.'
                      : r.description,
                  style: const TextStyle(height: 1.5),
                ),
              ),
              if (r.imagePath != null || r.audioPath != null) ...[
                const SizedBox(height: 16),
                _titreSection('Pièces jointes'),
                if (r.imagePath != null) ReclamationImage(path: r.imagePath!),
                if (r.audioPath != null) ...[
                  const SizedBox(height: 8),
                  _lecteurAudio(r.audioPath!, 'Message vocal de l’étudiant'),
                ],
              ],
              if (r.aiConseil != null) ...[
                const SizedBox(height: 16),
                _titreSection('Analyse de l’assistance IA'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaireDoux,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(r.aiConseil!),
                ),
              ],
              const SizedBox(height: 18),
              _titreSection('Échanges (${r.responses.length})'),
              if (r.responses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Aucune réponse pour le moment.',
                    style: TextStyle(color: AppColors.texte2),
                  ),
                )
              else
                ...r.responses.map(_bulle),
              if (!_isAdmin) _actionsEtudiant(r),
              if (peutEcrire) ...[
                const SizedBox(height: 16),
                _compositeur(r),
              ],
              const SizedBox(height: 16),
              _historique(r),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // En-tête : infos, statut, priorité, SLA
  // ---------------------------------------------------------------------

  Widget _entete(Reclamation r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    r.sujet,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ReclamationStatusChip(status: r.status),
              ],
            ),
            const SizedBox(height: 10),
            ReclamationInfoRow(label: 'Type', value: r.typeLabel),
            ReclamationInfoRow(label: 'Trajet', value: r.trajet),
            if (r.auteurNom != null)
              ReclamationInfoRow(label: 'Auteur', value: r.auteurNom!),
            ReclamationInfoRow(
              label: 'Date',
              value: DateFormat('dd MMM yyyy à HH:mm', 'fr_FR').format(r.date),
            ),
            ReclamationInfoRow(
              label: 'Échéance',
              value: DateFormat('dd MMM à HH:mm', 'fr_FR').format(r.echeance),
            ),
            if (r.sentiment != null)
              ReclamationInfoRow(label: 'Ton', value: r.sentiment!),
            if (r.nombreReouvertures > 0)
              ReclamationInfoRow(
                label: 'Réouvert',
                value: '${r.nombreReouvertures} fois',
              ),
            const SizedBox(height: 4),
            SlaIndicator(reclamation: r),
            const SizedBox(height: 14),
            if (_isAdmin) ...[
              Row(
                children: [
                  Expanded(child: _selecteurStatut(r)),
                  const SizedBox(width: 10),
                  Expanded(child: _selecteurPriorite(r)),
                ],
              ),
            ] else
              Row(children: [PrioriteBadge(priorite: r.priorite)]),
          ],
        ),
      ),
    );
  }

  Widget _selecteurStatut(Reclamation r) {
    final options = {r.status, ...r.status.transitionsAutorisees}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return DropdownButtonFormField<ReclamationStatus>(
      key: ValueKey('statut-${r.status}'),
      initialValue: r.status,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Statut',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: options
          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
          .toList(),
      onChanged: (value) async {
        if (value == null || value == r.status) return;
        String? motif;
        if (value == ReclamationStatus.rejetee) {
          motif = await _demanderTexte(
            titre: 'Motif du rejet',
            indice: 'Expliquez pourquoi la réclamation est rejetée',
          );
          if (motif == null) {
            setState(() {}); // réinitialise la liste déroulante
            return;
          }
        }
        _executer(() {
          ReclamationService.instance.mettreAJourStatut(
            r.id,
            value,
            auteur: _nomUtilisateur,
            motif: motif,
          );
          if (motif != null) {
            ReclamationService.instance.ajouterReponse(
              r.id,
              'Réclamation rejetée : $motif',
              auteurNom: _nomUtilisateur,
            );
          }
        });
      },
    );
  }

  Widget _selecteurPriorite(Reclamation r) {
    return DropdownButtonFormField<ReclamationPriorite>(
      key: ValueKey('priorite-${r.priorite}'),
      initialValue: r.priorite,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Priorité',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: ReclamationPriorite.values
          .map(
            (p) => DropdownMenuItem(
              value: p,
              child: Text(p.label, style: TextStyle(color: p.couleur)),
            ),
          )
          .toList(),
      onChanged: r.status.estCloturee
          ? null
          : (value) {
              if (value == null) return;
              ReclamationService.instance.changerPriorite(
                r.id,
                value,
                auteur: _nomUtilisateur,
              );
            },
    );
  }

  // ---------------------------------------------------------------------
  // Fil de discussion
  // ---------------------------------------------------------------------

  Widget _bulle(ReclamationResponse m) {
    final admin = m.parAdmin;
    return Align(
      alignment: admin ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: admin ? AppColors.primaireDoux : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(admin ? 4 : 16),
              bottomRight: Radius.circular(admin ? 16 : 4),
            ),
            border: Border.all(color: AppColors.bordure),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    admin
                        ? Icons.admin_panel_settings_rounded
                        : Icons.person_rounded,
                    size: 16,
                    color: admin ? AppColors.primaire : AppColors.texte2,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      admin
                          ? 'Administration${m.auteurNom != null ? ' · ${m.auteurNom}' : ''}'
                          : (m.auteurNom ?? 'Étudiant'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: admin ? AppColors.primaire : AppColors.texte2,
                      ),
                    ),
                  ),
                ],
              ),
              if (m.message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(m.message, style: const TextStyle(height: 1.4)),
              ],
              if (m.imagePath != null) ...[
                const SizedBox(height: 8),
                ReclamationImage(path: m.imagePath!, height: 180),
              ],
              if (m.audioPath != null) ...[
                const SizedBox(height: 8),
                _lecteurAudio(m.audioPath!, 'Écouter le vocal'),
              ],
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(m.date),
                style: const TextStyle(fontSize: 11, color: AppColors.texte2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lecteurAudio(String path, String libelle) {
    final enLecture = _currentlyPlayingPath == path;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaire.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              enLecture
                  ? Icons.stop_circle_rounded
                  : Icons.play_circle_fill_rounded,
              color: AppColors.primaire,
              size: 30,
            ),
            onPressed: () => _toggleAudio(path),
          ),
          Flexible(
            child: Text(
              enLecture ? 'Lecture en cours…' : libelle,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaire,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.graphic_eq_rounded, color: AppColors.primaire),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Actions étudiant : noter / rouvrir
  // ---------------------------------------------------------------------

  Widget _actionsEtudiant(Reclamation r) {
    if (r.status != ReclamationStatus.resolue) return const SizedBox.shrink();
    final refus = ReclamationService.instance.raisonRefusReouverture(r);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: _boite(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.satisfaction == null
                ? 'Êtes-vous satisfait du traitement ?'
                : 'Votre évaluation',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              final note = i + 1;
              final active = (r.satisfaction ?? 0) >= note;
              return IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  active ? Icons.star_rounded : Icons.star_border_rounded,
                  color: const Color(0xFFE5A100),
                  size: 32,
                ),
                onPressed: () => _noter(r, note),
              );
            }),
          ),
          if (r.commentaireSatisfaction != null)
            Text(
              '« ${r.commentaireSatisfaction} »',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.texte2,
              ),
            ),
          const Divider(height: 20),
          OutlinedButton.icon(
            onPressed: refus == null ? () => _rouvrir(r) : null,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Le problème persiste : rouvrir'),
          ),
          if (refus != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                refus,
                style: const TextStyle(fontSize: 12, color: AppColors.texte2),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _noter(Reclamation r, int note) async {
    String? commentaire;
    if (note <= 2) {
      commentaire = await _demanderTexte(
        titre: 'Qu’est-ce qui n’a pas été ?',
        indice: 'Votre commentaire (facultatif)',
        obligatoire: false,
      );
    }
    _executer(
      () => ReclamationService.instance.noter(
        r.id,
        note,
        commentaire: commentaire,
        auteur: _nomUtilisateur,
      ),
      succes: 'Merci pour votre évaluation !',
    );
  }

  Future<void> _rouvrir(Reclamation r) async {
    final motif = await _demanderTexte(
      titre: 'Rouvrir la réclamation',
      indice: 'Expliquez pourquoi le problème n’est pas résolu',
    );
    if (motif == null) return;
    _executer(
      () => ReclamationService.instance.rouvrir(
        r.id,
        motif,
        auteur: _nomUtilisateur,
      ),
      succes: 'Réclamation rouverte, priorité augmentée.',
    );
  }

  // ---------------------------------------------------------------------
  // Compositeur de réponse (texte + image + vocal + IA)
  // ---------------------------------------------------------------------

  Widget _compositeur(Reclamation r) {
    return Container(
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
          Row(
            children: [
              const Icon(Icons.reply_rounded, color: AppColors.primaire),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isAdmin ? 'Répondre à l’étudiant' : 'Ajouter un message',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaire,
                  ),
                ),
              ),
              if (_isAdmin)
                TextButton.icon(
                  onPressed: _suggestionEnCours ? null : () => _suggerer(r),
                  icon: _suggestionEnCours
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Suggérer'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _responseController,
            minLines: 2,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _isAdmin
                  ? 'Rédigez votre réponse, joignez une image ou un vocal…'
                  : 'Précision, preuve, nouvelle information…',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_reponseImage != null) ...[
            const SizedBox(height: 10),
            Stack(
              children: [
                ReclamationImage(path: _reponseImage!.path, height: 150),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _reponseImage = null),
                  ),
                ),
              ],
            ),
          ],
          if (_reponseAudioPath != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _lecteurAudio(_reponseAudioPath!, 'Aperçu du vocal'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Supprimer le vocal',
                  onPressed: () {
                    if (_currentlyPlayingPath == _reponseAudioPath) {
                      _audioChannel.invokeMethod<void>('stop');
                      _currentlyPlayingPath = null;
                    }
                    setState(() => _reponseAudioPath = null);
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Joindre une image',
                onPressed: _envoiEnCours ? null : _choisirImageReponse,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
              const SizedBox(width: 8),
              if (_isAdmin && _reponseAudioPath == null)
                IconButton.outlined(
                  tooltip: _enregistrementReponse
                      ? 'Arrêter l’enregistrement'
                      : 'Répondre par vocal',
                  onPressed: _envoiEnCours
                      ? null
                      : (_enregistrementReponse
                            ? _arreterReponseVocale
                            : _demarrerReponseVocale),
                  icon: Icon(
                    _enregistrementReponse
                        ? Icons.stop_circle_rounded
                        : Icons.mic_rounded,
                    color: _enregistrementReponse ? Colors.red : null,
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _envoiEnCours ? null : () => _envoyer(r),
                icon: _envoiEnCours
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_envoiEnCours ? 'Envoi…' : 'Envoyer'),
              ),
            ],
          ),
          if (_isAdmin && r.status == ReclamationStatus.enCours)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _resoudreApresEnvoi,
                onChanged: (v) =>
                    setState(() => _resoudreApresEnvoi = v ?? false),
                title: const Text('Marquer comme résolue après l’envoi'),
              ),
            ),
        ],
      ),
    );
  }

  bool _resoudreApresEnvoi = false;

  Future<void> _choisirImageReponse() async {
    final source = await choisirSourceImage(context);
    if (source == null) return;
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (image != null && mounted) setState(() => _reponseImage = image);
  }

  Future<void> _suggerer(Reclamation r) async {
    setState(() => _suggestionEnCours = true);
    try {
      final brouillon = await _ai.suggererReponse(r);
      if (!mounted) return;
      _responseController.text = brouillon;
      _responseController.selection = TextSelection.collapsed(
        offset: brouillon.length,
      );
      _afficher(
        _ai.estConfiguree
            ? 'Brouillon généré par DeepSeek — relisez avant d’envoyer.'
            : 'Modèle de réponse inséré (IA non configurée).',
      );
    } on ReclamationAiException catch (e) {
      _afficher(e.message);
    } finally {
      if (mounted) setState(() => _suggestionEnCours = false);
    }
  }

  Future<void> _demarrerReponseVocale() async {
    if (!await _responseRecorder.hasPermission()) {
      _afficher('L’accès au microphone est nécessaire.');
      return;
    }
    final path =
        '${Directory.systemTemp.path}/reponse_${DateTime.now().millisecondsSinceEpoch}.m4a';
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

  Future<void> _envoyer(Reclamation r) async {
    if (_enregistrementReponse) await _arreterReponseVocale();
    final texte = _responseController.text.trim();
    if (texte.isEmpty && _reponseAudioPath == null && _reponseImage == null) {
      _afficher('Saisissez un message, joignez une image ou un vocal.');
      return;
    }

    setState(() => _envoiEnCours = true);
    try {
      String? imageUrl;
      if (_reponseImage != null) {
        imageUrl =
            await SupabaseStorageService.instance.uploadImage(
              _reponseImage!.path,
            ) ??
            _reponseImage!.path; // repli local
      }
      String? audioUrl;
      if (_reponseAudioPath != null) {
        audioUrl =
            await SupabaseStorageService.instance.uploadAudio(
              _reponseAudioPath!,
            ) ??
            _reponseAudioPath;
      }

      final service = ReclamationService.instance;
      service.ajouterReponse(
        r.id,
        texte.isEmpty && audioUrl != null && imageUrl == null
            ? '🎤 Réponse vocale'
            : texte,
        audioPath: audioUrl,
        imagePath: imageUrl,
        parAdmin: _isAdmin,
        auteurNom: _nomUtilisateur,
      );
      if (_isAdmin && _resoudreApresEnvoi) {
        service.mettreAJourStatut(
          r.id,
          ReclamationStatus.resolue,
          auteur: _nomUtilisateur,
        );
      }

      if (!mounted) return;
      _responseController.clear();
      setState(() {
        _reponseAudioPath = null;
        _reponseImage = null;
        _resoudreApresEnvoi = false;
      });
      _afficher('Message envoyé.');
    } on ReclamationRegleException catch (e) {
      _afficher(e.message);
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  // ---------------------------------------------------------------------
  // Historique
  // ---------------------------------------------------------------------

  Widget _historique(Reclamation r) {
    if (r.historique.isEmpty) return const SizedBox.shrink();
    final evenements = [...r.historique]
      ..sort((a, b) => b.date.compareTo(a.date));
    return Container(
      decoration: _boite(),
      child: ExpansionTile(
        shape: const Border(),
        leading: const Icon(Icons.history_rounded),
        title: Text('Historique (${evenements.length})'),
        children: evenements
            .map(
              (e) => ListTile(
                dense: true,
                leading: const Icon(Icons.circle, size: 10),
                title: Text(e.libelle),
                subtitle: Text(
                  '${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(e.date)}'
                  '${e.auteur != null ? ' · ${e.auteur}' : ''}',
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Outils
  // ---------------------------------------------------------------------

  void _executer(VoidCallback action, {String? succes}) {
    try {
      action();
      if (succes != null) _afficher(succes);
    } on ReclamationRegleException catch (e) {
      setState(() {});
      _afficher(e.message);
    }
  }

  Future<String?> _demanderTexte({
    required String titre,
    required String indice,
    bool obligatoire = true,
  }) async {
    final controller = TextEditingController();
    final resultat = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: indice,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (obligatoire && v.isEmpty) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    controller.dispose();
    return resultat;
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
      _afficher('Impossible de lire le vocal : ${error.message}');
    } on MissingPluginException {
      _afficher('Lecture audio non disponible sur cette plateforme.');
    }
  }

  void _afficher(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _titreSection(String texte) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texte,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );

  BoxDecoration _boite() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.bordure),
  );
}
