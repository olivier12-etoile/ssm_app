class Utilisateur {
  final int id;
  final String nom;
  final String email;
  final String role;
  final int ecoleId;
  final String codeEcole;
  final String couleurPrimaire;
  final String couleurSecondaire;
  final bool motDePasseChange;

  Utilisateur({
    required this.id,
    required this.nom,
    required this.email,
    required this.role,
    required this.ecoleId,
    required this.codeEcole,
    required this.couleurPrimaire,
    required this.couleurSecondaire,
    required this.motDePasseChange,
  });

  factory Utilisateur.fromJson(Map<String, dynamic> json) {
    return Utilisateur(
      id:                 json['id'] as int,
      nom:                json['nom'] as String,
      email:              json['email'] as String,
      role:               json['role'] as String,
      ecoleId:            json['ecole_id'] as int,
      codeEcole:          json['code_ecole'] as String,
      couleurPrimaire:    json['couleur_primaire'] as String,
      couleurSecondaire:  json['couleur_secondaire'] as String,
      motDePasseChange:   json['mot_de_passe_change'] as bool,
    );
  }

  bool get estDirecteur  => role == 'directeur';
  bool get estCenseur    => role == 'censeur';
  bool get estSecretaire => role == 'secretaire';
  bool get estEnseignant => role == 'enseignant';
}