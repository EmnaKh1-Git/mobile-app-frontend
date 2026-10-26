import '../../../features/user/services/user_service.dart';

class ContexteUtilisateur {
  ContexteUtilisateur._();
  static final ContexteUtilisateur instance = ContexteUtilisateur._();

  String? get idConnecte => UserService.instance.currentUser?.id;
  String? get nomConnecte {
    final u = UserService.instance.currentUser;
    if (u == null) return null;
    final nom = '${u.prenom} ${u.nom}'.trim();
    return nom.isEmpty ? null : nom;
  }
  bool get estConnecte => UserService.instance.currentUser != null;
}
