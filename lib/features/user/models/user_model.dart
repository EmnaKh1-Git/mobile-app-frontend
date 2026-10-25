enum UserRole {
  passager,
  conducteur,
  administrateur;

  String get label {
    switch (this) {
      case UserRole.passager:
        return 'Passager';
      case UserRole.conducteur:
        return 'Conducteur';
      case UserRole.administrateur:
        return 'Administrateur';
    }
  }

  bool get isConducteur => this == UserRole.conducteur;
  bool get isPassager => this == UserRole.passager;
  bool get isAdmin => this == UserRole.administrateur;
}

class UserModel {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final String indicatifTel;
  final UserRole role;
  final String? avatarUrl;
  final String gouvernorat;
  final String universite;
  final double note;
  final int nombreTrajets;
  final String? marqueVehicule;
  final String? modeleVehicule;
  final String? couleurVehicule;
  final String? immatriculation;
  final int placesDisponibles;
  final DateTime? dateInscription;
  final bool isBanni;
  final bool isBloque;
  final String? raisonBlocage;

  const UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    this.indicatifTel = '+216',
    required this.role,
    this.avatarUrl,
    this.gouvernorat = 'Tunis',
    this.universite = 'ESPRIT',
    this.note = 4.9,
    this.nombreTrajets = 12,
    this.marqueVehicule,
    this.modeleVehicule,
    this.couleurVehicule,
    this.immatriculation,
    this.placesDisponibles = 3,
    this.dateInscription,
    this.isBanni = false,
    this.isBloque = false,
    this.raisonBlocage,
  });

  String get nomComplet => '$prenom $nom';
  String get telephoneComplet => '$indicatifTel $telephone';
  bool get isConducteur => role == UserRole.conducteur;
  bool get isPassager => role == UserRole.passager;
  bool get isAdmin => role == UserRole.administrateur;

  UserModel copyWith({
    String? id,
    String? nom,
    String? prenom,
    String? email,
    String? telephone,
    String? indicatifTel,
    UserRole? role,
    String? avatarUrl,
    String? gouvernorat,
    String? universite,
    double? note,
    int? nombreTrajets,
    String? marqueVehicule,
    String? modeleVehicule,
    String? couleurVehicule,
    String? immatriculation,
    int? placesDisponibles,
    DateTime? dateInscription,
    bool? isBanni,
    bool? isBloque,
    String? raisonBlocage,
  }) {
    return UserModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      indicatifTel: indicatifTel ?? this.indicatifTel,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gouvernorat: gouvernorat ?? this.gouvernorat,
      universite: universite ?? this.universite,
      note: note ?? this.note,
      nombreTrajets: nombreTrajets ?? this.nombreTrajets,
      marqueVehicule: marqueVehicule ?? this.marqueVehicule,
      modeleVehicule: modeleVehicule ?? this.modeleVehicule,
      couleurVehicule: couleurVehicule ?? this.couleurVehicule,
      immatriculation: immatriculation ?? this.immatriculation,
      placesDisponibles: placesDisponibles ?? this.placesDisponibles,
      dateInscription: dateInscription ?? this.dateInscription,
      isBanni: isBanni ?? this.isBanni,
      isBloque: isBloque ?? this.isBloque,
      raisonBlocage: raisonBlocage ?? this.raisonBlocage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'indicatifTel': indicatifTel,
      'role': role.name,
      'avatarUrl': avatarUrl,
      'gouvernorat': gouvernorat,
      'universite': universite,
      'note': note,
      'nombreTrajets': nombreTrajets,
      'marqueVehicule': marqueVehicule,
      'modeleVehicule': modeleVehicule,
      'couleurVehicule': couleurVehicule,
      'immatriculation': immatriculation,
      'placesDisponibles': placesDisponibles,
      'dateInscription': dateInscription?.toIso8601String(),
      'isBanni': isBanni,
      'isBloque': isBloque,
      'raisonBlocage': raisonBlocage,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    UserRole parsedRole;
    final r = map['role']?.toString().toLowerCase();
    if (r == 'administrateur' || r == 'admin') {
      parsedRole = UserRole.administrateur;
    } else if (r == 'conducteur') {
      parsedRole = UserRole.conducteur;
    } else {
      parsedRole = UserRole.passager;
    }

    return UserModel(
      id: map['id'] ?? '',
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      email: map['email'] ?? '',
      telephone: map['telephone'] ?? '',
      indicatifTel: map['indicatifTel'] ?? '+216',
      role: parsedRole,
      avatarUrl: map['avatarUrl'],
      gouvernorat: map['gouvernorat'] ?? 'Tunis',
      universite: map['universite'] ?? 'ESPRIT',
      note: (map['note'] as num?)?.toDouble() ?? 4.9,
      nombreTrajets: map['nombreTrajets'] ?? 0,
      marqueVehicule: map['marqueVehicule'],
      modeleVehicule: map['modeleVehicule'],
      couleurVehicule: map['couleurVehicule'],
      immatriculation: map['immatriculation'],
      placesDisponibles: map['placesDisponibles'] ?? 3,
      dateInscription: map['dateInscription'] != null
          ? DateTime.tryParse(map['dateInscription'])
          : null,
      isBanni: map['isBanni'] == true || map['isBanni'] == 1,
      isBloque: map['isBloque'] == true || map['isBloque'] == 1,
      raisonBlocage: map['raisonBlocage'],
    );
  }
}
