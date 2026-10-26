// ============================================================
// MODELE MEMBRE D'UNE CONVERSATION
// ============================================================

enum RoleMembre {
  conducteur,
  passager,
}

class Membre {
  final String id;
  final String nom;
  final RoleMembre role;
  final DateTime? lastReadAt;

  const Membre({
    required this.id,
    required this.nom,
    this.role = RoleMembre.passager,
    this.lastReadAt,
  });

  Membre copyWith({
    String? id,
    String? nom,
    RoleMembre? role,
    DateTime? lastReadAt,
  }) {
    return Membre(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      role: role ?? this.role,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': id,
      'nom': nom,
      'role': role.name,
      'last_read_at': lastReadAt?.toIso8601String(),
    };
  }

  factory Membre.fromMap(Map<String, dynamic> map) {
    return Membre(
      id: map['user_id'].toString(),
      nom: map['nom']?.toString() ?? '',
      role: map['role']?.toString() == RoleMembre.conducteur.name
          ? RoleMembre.conducteur
          : RoleMembre.passager,
      lastReadAt: map['last_read_at'] != null
          ? DateTime.tryParse(map['last_read_at'].toString())
          : null,
    );
  }

  bool get estConducteur => role == RoleMembre.conducteur;

  String get initiale {
    if (nom.trim().isEmpty) return '?';
    return nom.trim()[0].toUpperCase();
  }
}
