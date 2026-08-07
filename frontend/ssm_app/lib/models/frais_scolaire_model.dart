String formatDateApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class EcheanceFrais {
  final int? id;
  final String libelle;
  final double montant;
  final DateTime dateLimite;
  final int ordre;

  EcheanceFrais({
    this.id,
    required this.libelle,
    required this.montant,
    required this.dateLimite,
    this.ordre = 1,
  });

  factory EcheanceFrais.fromJson(Map<String, dynamic> json) {
    return EcheanceFrais(
      id: json['id'] as int?,
      libelle: json['libelle'] as String,
      montant: double.parse(json['montant'].toString()),
      dateLimite: DateTime.parse(json['date_limite'] as String),
      ordre: (json['ordre'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'libelle': libelle,
      'montant': montant,
      'date_limite': formatDateApi(dateLimite),
      'ordre': ordre,
    };
  }

  EcheanceFrais copyWith({
    String? libelle,
    double? montant,
    DateTime? dateLimite,
    int? ordre,
  }) {
    return EcheanceFrais(
      id: id,
      libelle: libelle ?? this.libelle,
      montant: montant ?? this.montant,
      dateLimite: dateLimite ?? this.dateLimite,
      ordre: ordre ?? this.ordre,
    );
  }
}

class FraisScolaire {
  final int? id;
  final String nom;
  final String? description;
  final double montant;
  final int? classeId;
  final String? classeNom;
  final String? serie;
  final int anneeScolaireId;
  final DateTime dateLimite;
  final bool obligatoire;
  final bool actif;
  final List<EcheanceFrais> echeances;

  FraisScolaire({
    this.id,
    required this.nom,
    this.description,
    required this.montant,
    this.classeId,
    this.classeNom,
    this.serie,
    required this.anneeScolaireId,
    required this.dateLimite,
    this.obligatoire = true,
    this.actif = true,
    this.echeances = const [],
  });

  factory FraisScolaire.fromJson(Map<String, dynamic> json) {
    return FraisScolaire(
      id: json['id'] as int?,
      nom: json['nom'] as String,
      description: json['description'] as String?,
      montant: double.parse(json['montant'].toString()),
      classeId: json['classe_id'] as int?,
      classeNom: json['classe'] is Map ? json['classe']['nom'] as String? : null,
      serie: json['serie'] as String?,
      anneeScolaireId: json['annee_scolaire_id'] as int,
      dateLimite: DateTime.parse(json['date_limite'] as String),
      obligatoire: json['obligatoire'] == true || json['obligatoire'] == 1,
      actif: json['actif'] == true || json['actif'] == 1,
      echeances: (json['echeances'] as List? ?? [])
          .map((e) => EcheanceFrais.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'description': description,
      'montant': montant,
      'classe_id': classeId,
      'serie': serie,
      'annee_scolaire_id': anneeScolaireId,
      'date_limite': formatDateApi(dateLimite),
      'obligatoire': obligatoire,
      'actif': actif,
      if (echeances.isNotEmpty)
        'echeances': echeances.map((e) => e.toJson()).toList(),
    };
  }

  double get montantEcheances =>
      echeances.fold(0, (total, e) => total + e.montant);

  FraisScolaire copyWith({
    String? nom,
    String? description,
    double? montant,
    int? classeId,
    bool effacerClasse = false,
    String? serie,
    int? anneeScolaireId,
    DateTime? dateLimite,
    bool? obligatoire,
    bool? actif,
    List<EcheanceFrais>? echeances,
  }) {
    return FraisScolaire(
      id: id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      montant: montant ?? this.montant,
      classeId: effacerClasse ? null : (classeId ?? this.classeId),
      classeNom: classeNom,
      serie: serie ?? this.serie,
      anneeScolaireId: anneeScolaireId ?? this.anneeScolaireId,
      dateLimite: dateLimite ?? this.dateLimite,
      obligatoire: obligatoire ?? this.obligatoire,
      actif: actif ?? this.actif,
      echeances: echeances ?? this.echeances,
    );
  }
}
