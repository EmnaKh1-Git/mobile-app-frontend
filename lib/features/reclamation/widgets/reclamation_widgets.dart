import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/reclamation.dart';

String formatDuree(Duration d) {
  final negatif = d.isNegative;
  final abs = d.abs();
  String texte;
  if (abs.inDays >= 1) {
    final h = abs.inHours % 24;
    texte = '${abs.inDays} j${h > 0 ? ' $h h' : ''}';
  } else if (abs.inHours >= 1) {
    texte = '${abs.inHours} h ${abs.inMinutes % 60} min';
  } else {
    texte = '${abs.inMinutes} min';
  }
  return negatif ? '-$texte' : texte;
}

class ReclamationStatusChip extends StatelessWidget {
  final ReclamationStatus status;

  const ReclamationStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color fond, Color texte) = switch (status) {
      ReclamationStatus.enAttente => (
        const Color(0xFFFFF3CD),
        const Color(0xFF8A6D1C),
      ),
      ReclamationStatus.enCours => (
        const Color(0xFFE6F4FF),
        const Color(0xFF0057B8),
      ),
      ReclamationStatus.resolue => (
        const Color(0xFFE8F7E9),
        const Color(0xFF1E7E34),
      ),
      ReclamationStatus.rejetee => (
        const Color(0xFFFDECEA),
        const Color(0xFFB3261E),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: texte,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class PrioriteBadge extends StatelessWidget {
  final ReclamationPriorite priorite;
  final bool compact;

  const PrioriteBadge({super.key, required this.priorite, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final couleur = priorite.couleur;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            priorite == ReclamationPriorite.urgente
                ? Icons.priority_high_rounded
                : Icons.flag_rounded,
            size: compact ? 12 : 14,
            color: couleur,
          ),
          const SizedBox(width: 3),
          Text(
            priorite.label,
            style: TextStyle(
              color: couleur,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur de délai de traitement (SLA).
class SlaIndicator extends StatelessWidget {
  final Reclamation reclamation;

  const SlaIndicator({super.key, required this.reclamation});

  @override
  Widget build(BuildContext context) {
    final r = reclamation;
    if (r.status.estCloturee) {
      final dans = r.dateCloture != null && !r.dateCloture!.isAfter(r.echeance);
      return _ligne(
        dans ? Icons.verified_rounded : Icons.history_toggle_off_rounded,
        r.dateCloture == null
            ? 'Clôturée'
            : dans
            ? 'Traitée dans les délais'
            : 'Traitée hors délai',
        dans ? AppColors.succes : AppColors.alerte,
      );
    }
    if (r.estEnRetard) {
      return _ligne(
        Icons.warning_amber_rounded,
        'Délai dépassé de ${formatDuree(-r.tempsRestant)}',
        const Color(0xFFC62828),
      );
    }
    final restant = r.tempsRestant;
    final critique = restant.inMinutes < r.priorite.sla.inMinutes * 0.25;
    return _ligne(
      Icons.timer_outlined,
      'Réponse attendue sous ${formatDuree(restant)}',
      critique ? AppColors.alerte : AppColors.texte2,
    );
  }

  Widget _ligne(IconData icone, String texte, Color couleur) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icone, size: 15, color: couleur),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          texte,
          style: TextStyle(
            fontSize: 12,
            color: couleur,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

/// Image locale ou distante, cliquable pour un affichage plein écran.
class ReclamationImage extends StatelessWidget {
  final String path;
  final double height;

  const ReclamationImage({super.key, required this.path, this.height = 220});

  static bool estDistante(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  static ImageProvider provider(String path) => estDistante(path)
      ? NetworkImage(path)
      : FileImage(File(path)) as ImageProvider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ImagePleinEcran(path: path)),
      ),
      child: Hero(
        tag: path,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(
            image: provider(path),
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: height,
                color: AppColors.champFond,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              height: height,
              color: AppColors.champFond,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image,
                size: 48,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePleinEcran extends StatelessWidget {
  final String path;

  const _ImagePleinEcran({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Hero(
          tag: path,
          child: InteractiveViewer(
            maxScale: 5,
            child: Image(image: ReclamationImage.provider(path)),
          ),
        ),
      ),
    );
  }
}

class ReclamationInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const ReclamationInfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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
