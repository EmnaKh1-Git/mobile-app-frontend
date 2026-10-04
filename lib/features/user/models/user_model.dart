enum UserRole {
  passager,
  conducteur;

  String get label {
    switch (this) {
      case UserRole.passager:
        return 'Passager';
      case UserRole.conducteur:
        return 'Conducteur';
    }
  }

  bool get isConducteur => this == UserRole.conducteur;
  bool get isPassager => this == UserRole.passager;
}

class UserModel {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final UserRole role;
  final String? avatarUrl;
  final String universite;
  final double note;
  final int nombreTrajets;
  final String? immatriculation;
  final String? modeleVehicule;
  final String? couleurVehicule;
  final DateTime? dateInscription;

  const UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.role,
    this.avatarUrl,
    this.universite = 'Université Campus Sud',
    this.note = 4.9,
    this.nombreTrajets = 12,
    this.immatriculation,
    this.modeleVehicule,
    this.couleurVehicule,
    this.dateInscription,
  });

  String get nomComplet => '$prenom $nom';
  bool get isConducteur => role == UserRole.conducteur;
  bool get isPassager => role == UserRole.passager;

  UserModel copyWith({
    String? id,
    String? nom,
    String? prenom,
    String? email,
    String? telephone,
    UserRole? role,
    String? avatarUrl,
    String? universite,
    double? note,
    int? nombreTrajets,
    String? immatriculation,
    String? modeleVehicule,
    String? couleurVehicule,
    DateTime? dateInscription,
  }) {
    return UserModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      universite: universite ?? this.universite,
      note: note ?? this.note,
      nombreTrajets: nombreTrajets ?? this.nombreTrajets,
      immatriculation: immatriculation ?? this.immatriculation,
      modeleVehicule: modeleVehicule ?? this.modeleVehicule,
      couleurVehicule: couleurVehicule ?? this.couleurVehicule,
      dateInscription: dateInscription ?? this.dateInscription,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'role': role.name,
      'avatarUrl': avatarUrl,
      'universite': universite,
      'note': note,
      'nombreTrajets': nombreTrajets,
      'immatriculation': immatriculation,
      'modeleVehicule': modeleVehicule,
      'couleurVehicule': couleurVehicule,
      'dateInscription': dateInscription?.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      email: map['email'] ?? '',
      telephone: map['telephone'] ?? '',
      role: map['role'] == 'conducteur' ? UserRole.conducteur : UserRole.passager,
      avatarUrl: map['avatarUrl'],
      universite: map['universite'] ?? 'Université Campus Sud',
      note: (map['note'] as num?)?.toDouble() ?? 4.9,
      nombreTrajets: map['nombreTrajets'] ?? 0,
      immatriculation: map['immatriculation'],
      modeleVehicule: map['modeleVehicule'],
      couleurVehicule: map['couleurVehicule'],
      dateInscription: map['dateInscription'] != null
          ? DateTime.tryParse(map['dateInscription'])
          : null,
    );
  }
}
