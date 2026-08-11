// ══════════════════════════════════════════════════════════
// Enum TypeEvaluation
// ══════════════════════════════════════════════════════════
enum TypeEvaluation {
  devoir('devoir', 'Devoir'),
  composition('composition', 'Composition');

  final String valeurApi;
  final String libelle;

  const TypeEvaluation(this.valeurApi, this.libelle);

  static TypeEvaluation depuisApi(String valeur) => TypeEvaluation.values.firstWhere(
        (t) => t.valeurApi == valeur,
        orElse: () => TypeEvaluation.devoir,
      );
}

// ══════════════════════════════════════════════════════════
// Enum StatutSaisie (statut de saisies_notes)
// ══════════════════════════════════════════════════════════
enum StatutSaisie {
  enCours('en_cours', 'En cours'),
  terminee('terminee', 'Terminée'),
  enAttenteValidation('en_attente_validation', 'En attente de validation'),
  validee('validee', 'Validée'),
  rejetee('rejetee', 'Rejetée');

  final String valeurApi;
  final String libelle;

  const StatutSaisie(this.valeurApi, this.libelle);

  static StatutSaisie depuisApi(String valeur) => StatutSaisie.values.firstWhere(
        (s) => s.valeurApi == valeur,
        orElse: () => StatutSaisie.enCours,
      );
}

// ══════════════════════════════════════════════════════════
// Note
// ══════════════════════════════════════════════════════════
class Note {
  final int? id;
  final int eleveId;
  final int matiereId;
  final int classeId;
  final int periodeId;
  final double valeur;
  final TypeEvaluation typeEvaluation;
  final double coefficient;
  // Statut de la note elle-même : brouillon | en_attente_validation |
  // validee | rejetee (vocabulaire différent de StatutSaisie, qui décrit
  // l'état de la session de saisie).
  final String statut;
  final int? saisiPar;
  final int? valideePar;
  final DateTime? dateValidation;
  final String? motifRejet;

  Note({
    this.id,
    required this.eleveId,
    required this.matiereId,
    required this.classeId,
    required this.periodeId,
    required this.valeur,
    required this.typeEvaluation,
    this.coefficient = 1,
    this.statut = 'brouillon',
    this.saisiPar,
    this.valideePar,
    this.dateValidation,
    this.motifRejet,
  });

  bool get estModifiable => statut == 'brouillon';

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as int?,
      eleveId: json['eleve_id'] as int,
      matiereId: json['matiere_id'] as int,
      classeId: json['classe_id'] as int,
      periodeId: json['periode_id'] as int,
      valeur: double.parse(json['valeur'].toString()),
      typeEvaluation: TypeEvaluation.depuisApi(json['type_evaluation'] as String),
      coefficient: double.parse((json['coefficient'] ?? 1).toString()),
      statut: json['statut'] as String? ?? 'brouillon',
      saisiPar: json['saisi_par'] as int?,
      valideePar: json['valide_par'] as int?,
      dateValidation:
          json['date_validation'] != null ? DateTime.tryParse(json['date_validation'].toString()) : null,
      motifRejet: json['motif_rejet'] as String?,
    );
  }

  // Corps de requête pour POST /notes et POST /notes/bulk.
  Map<String, dynamic> toJson() {
    return {
      'eleve_id': eleveId,
      'matiere_id': matiereId,
      'classe_id': classeId,
      'periode_id': periodeId,
      'type_evaluation': typeEvaluation.valeurApi,
      'valeur': valeur,
    };
  }
}

// ══════════════════════════════════════════════════════════
// EleveSaisie — élève d'une saisie avec ses notes devoir/composition
// (nécessaire pour construire le tableau de saisie ; retourné par
// GET /notes/saisie/{id}/eleves).
// ══════════════════════════════════════════════════════════
class EleveSaisie {
  final int eleveId;
  final String nom;
  final String prenom;
  final String? matricule;
  final Note? noteDevoir;
  final Note? noteComposition;

  EleveSaisie({
    required this.eleveId,
    required this.nom,
    required this.prenom,
    this.matricule,
    this.noteDevoir,
    this.noteComposition,
  });

  String get nomComplet => '$nom $prenom';

  Note? notePourType(TypeEvaluation type) =>
      type == TypeEvaluation.devoir ? noteDevoir : noteComposition;

  factory EleveSaisie.fromJson(Map<String, dynamic> json) {
    return EleveSaisie(
      eleveId: json['eleve_id'] as int,
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      matricule: json['matricule'] as String?,
      noteDevoir: json['note_devoir'] != null ? Note.fromJson(json['note_devoir'] as Map<String, dynamic>) : null,
      noteComposition:
          json['note_composition'] != null ? Note.fromJson(json['note_composition'] as Map<String, dynamic>) : null,
    );
  }
}

// ══════════════════════════════════════════════════════════
// SaisieNote
// ══════════════════════════════════════════════════════════
class SaisieNote {
  final int id;
  final int enseignantId;
  final int classeId;
  final int matiereId;
  final int periodeId;
  final StatutSaisie statut;
  final DateTime? dateDebut;
  final DateTime? dateFinSaisie;
  final DateTime? dateSoumission;
  final double? pourcentageCompletion;

  // Champs de confort (libellés déjà résolus par le backend selon
  // l'endpoint : classe/matiere/periode imbriqués sur demarrer()/eleves(),
  // ou classe_nom/matiere_nom/periode_nom à plat sur progression()).
  final String? classeNom;
  final String? matiereNom;
  final String? periodeNom;
  final int? nbEleves;
  final int? nbNotesSaisies;

  SaisieNote({
    required this.id,
    required this.enseignantId,
    required this.classeId,
    required this.matiereId,
    required this.periodeId,
    required this.statut,
    this.dateDebut,
    this.dateFinSaisie,
    this.dateSoumission,
    this.pourcentageCompletion,
    this.classeNom,
    this.matiereNom,
    this.periodeNom,
    this.nbEleves,
    this.nbNotesSaisies,
  });

  factory SaisieNote.fromJson(Map<String, dynamic> json) {
    final classe = json['classe'] as Map<String, dynamic>?;
    final matiere = json['matiere'] as Map<String, dynamic>?;
    final periode = json['periode'] as Map<String, dynamic>?;

    return SaisieNote(
      id: json['id'] as int,
      enseignantId: json['enseignant_id'] as int,
      classeId: json['classe_id'] as int,
      matiereId: json['matiere_id'] as int,
      periodeId: json['periode_id'] as int,
      statut: StatutSaisie.depuisApi(json['statut'] as String),
      dateDebut: json['date_debut'] != null ? DateTime.tryParse(json['date_debut'].toString()) : null,
      dateFinSaisie:
          json['date_fin_saisie'] != null ? DateTime.tryParse(json['date_fin_saisie'].toString()) : null,
      dateSoumission:
          json['date_soumission'] != null ? DateTime.tryParse(json['date_soumission'].toString()) : null,
      pourcentageCompletion: json['pourcentage_completion'] != null
          ? double.tryParse(json['pourcentage_completion'].toString())
          : null,
      classeNom: json['classe_nom'] as String? ?? classe?['nom'] as String?,
      matiereNom: json['matiere_nom'] as String? ?? matiere?['nom'] as String?,
      periodeNom: json['periode_nom'] as String? ?? periode?['nom'] as String?,
      nbEleves: json['nb_eleves'] as int?,
      nbNotesSaisies: json['nb_notes_saisies'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'enseignant_id': enseignantId,
      'classe_id': classeId,
      'matiere_id': matiereId,
      'periode_id': periodeId,
      'statut': statut.valeurApi,
    };
  }
}

// ══════════════════════════════════════════════════════════
// AnomalieNote — détail d'une alerte détectée par le backend
// (StatistiquesSaisie.anomalies expose déjà les messages à plat ; cette
// classe conserve le type/la gravité pour la mise en forme des bannières).
// ══════════════════════════════════════════════════════════
class AnomalieNote {
  final String type;
  final String gravite; // 'avertissement' | 'critique'
  final String message;

  AnomalieNote({required this.type, required this.gravite, required this.message});

  factory AnomalieNote.fromJson(Map<String, dynamic> json) {
    return AnomalieNote(
      type: json['type'] as String,
      gravite: json['gravite'] as String,
      message: json['message'] as String,
    );
  }
}

// ══════════════════════════════════════════════════════════
// StatistiquesSaisie
// ══════════════════════════════════════════════════════════
class StatistiquesSaisie {
  final double? moyenne;
  final double? meilleureNote;
  final double? plusFaibleNote;
  final double tauxReussite;
  final List<String> anomalies;
  final List<AnomalieNote> anomaliesDetail;

  StatistiquesSaisie({
    this.moyenne,
    this.meilleureNote,
    this.plusFaibleNote,
    required this.tauxReussite,
    required this.anomalies,
    required this.anomaliesDetail,
  });

  bool get aDesAnomaliesCritiques => anomaliesDetail.any((a) => a.gravite == 'critique');

  factory StatistiquesSaisie.fromJson(Map<String, dynamic> json) {
    final anomaliesJson = (json['anomalies'] as List? ?? [])
        .map((a) => AnomalieNote.fromJson(a as Map<String, dynamic>))
        .toList();

    return StatistiquesSaisie(
      moyenne: json['moyenne_classe'] != null ? double.tryParse(json['moyenne_classe'].toString()) : null,
      meilleureNote: json['meilleure_note'] != null ? double.tryParse(json['meilleure_note'].toString()) : null,
      plusFaibleNote:
          json['plus_faible_note'] != null ? double.tryParse(json['plus_faible_note'].toString()) : null,
      tauxReussite: double.tryParse((json['taux_reussite'] ?? 0).toString()) ?? 0,
      anomalies: anomaliesJson.map((a) => a.message).toList(),
      anomaliesDetail: anomaliesJson,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'moyenne_classe': moyenne,
      'meilleure_note': meilleureNote,
      'plus_faible_note': plusFaibleNote,
      'taux_reussite': tauxReussite,
      'anomalies': anomaliesDetail
          .map((a) => {'type': a.type, 'gravite': a.gravite, 'message': a.message})
          .toList(),
    };
  }
}
