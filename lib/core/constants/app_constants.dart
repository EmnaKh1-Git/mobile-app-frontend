import '../../features/user/services/user_service.dart';

// ------------------------------------------------------------
// Identité de l'utilisateur connecté pour les modules Trajets,
// Discussions et Notifications.
//
// Ces modules identifient les personnes par un entier (conducteur_id,
// passager_id… en bigint dans Supabase) alors que le module User
// utilise un identifiant texte (« usr_1730000000000 »). idTrajetDe()
// fait le lien : les chiffres de l'identifiant, ou à défaut un hachage
// stable. Sans utilisateur connecté (tests, démonstration), on garde
// l'identité de démonstration (1, « Hajer »).
// ------------------------------------------------------------

/// Identité de démonstration utilisée quand personne n'est connecté
const int monIdParDefaut = 1;
const String monNomParDefaut = 'Hajer';

/// Identifiant numérique (modules Trajets) de l'utilisateur connecté
int get monId {
  final id = UserService.instance.currentUser?.id;
  return id == null || id.isEmpty ? monIdParDefaut : idTrajetDe(id);
}

/// Nom affiché (« Prénom Nom ») de l'utilisateur connecté
String get monNom {
  final u = UserService.instance.currentUser;
  if (u == null) return monNomParDefaut;
  final nom = '${u.prenom} ${u.nom}'.trim();
  return nom.isEmpty ? monNomParDefaut : nom;
}

/// Convertit l'identifiant texte d'un utilisateur en identifiant numérique.
/// « usr_1001 » → 1001 ; « usr_admin_principal » → hachage FNV-1a stable.
int idTrajetDe(String userId) {
  final chiffres = userId.replaceAll(RegExp(r'\D'), '');
  if (chiffres.isNotEmpty && chiffres.length <= 15) {
    return int.parse(chiffres);
  }
  var hash = 0x811c9dc5;
  for (final unite in userId.codeUnits) {
    hash ^= unite;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
