import '../data/mots_interdits.dart';

// ============================================================
// FILTRE DE CONTENU (anti-abus)
// Détection locale de mots interdits, sans package externe.
// ============================================================

class FiltreContenu {
  FiltreContenu._();

  static final FiltreContenu instance = FiltreContenu._();

  /// Mots interdits normalisés (une seule fois).
  static final List<String> _motsNormalises = [
    for (final mot in motsInterdits)
      if (mot.trim().isNotEmpty) normaliser(mot),
  ]..sort((a, b) => b.length.compareTo(a.length));

  // ---------------------------------------------------------
  // NORMALISATION
  // ---------------------------------------------------------

  /// Minuscules, sans accents ni substitutions, sans
  /// caractères répétés ni séparateurs insérés entre lettres.
  static String normaliser(String texte) {
    var resultat = texte.toLowerCase();

    resultat = _sansAccents(resultat);
    resultat = _sansSubstitutions(resultat);

    // Supprime les séparateurs insérés entre les lettres
    // (ex. « m.e.r.d.e » ou « m e r d e » → « merde »).
    resultat = resultat.replaceAll(
      RegExp(r'[.\-_* ]+'),
      '',
    );

    // Réduit les caractères répétés (ex. « meeerde » → « merde »).
    resultat = resultat.replaceAll(
      RegExp(r'(.)\1+'),
      r'$1',
    );

    return resultat;
  }

  static String _sansAccents(String texte) {
    const accents =
        'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
    const sans =
        'aaaaaaceeeeiiiinooooouuuuyyea';

    final tampon = StringBuffer();

    for (final rune in texte.runes) {
      final caractere = String.fromCharCode(rune);
      final index = accents.indexOf(caractere);
      tampon.write(
        index == -1 ? caractere : sans[index],
      );
    }

    return tampon.toString();
  }

  static String _sansSubstitutions(String texte) {
    const substitutions = {
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '@': 'a',
      r'$': 's',
    };

    var resultat = texte;
    substitutions.forEach((cle, valeur) {
      resultat = resultat.replaceAll(cle, valeur);
    });
    return resultat;
  }

  // ---------------------------------------------------------
  // DÉTECTION
  // ---------------------------------------------------------

  /// Vrai si le texte contient un mot interdit (mots entiers).
  bool contientMotInterdit(String texte) {
    final normalise = normaliser(texte);
    if (normalise.isEmpty) return false;

    for (final mot in _motsNormalises) {
      if (RegExp('(^|[^a-z])$mot([^a-z]|\$)')
          .hasMatch(normalise)) {
        return true;
      }
    }

    return false;
  }

  /// Remplace chaque mot interdit par des astérisques de
  /// même longueur (ex. « merde » → « ***** »).
  String masquer(String texte) {
    var resultat = texte;

    // On boucle sur le texte réel pour préserver les positions.
    for (final mot in motsInterdits) {
      if (mot.trim().isEmpty) continue;

      final motif = RegExp(
        RegExp.escape(mot),
        caseSensitive: false,
      );

      resultat = resultat.replaceAllMapped(
        motif,
        (m) => '*' * m.group(0)!.length,
      );
    }

    return resultat;
  }
}
