import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════
// StatutBulletin — genere → valide → verrouille (voir
// ValidationBulletinController côté backend pour le détail du workflow)
// ══════════════════════════════════════════════════════════
enum StatutBulletin {
  genere('genere', 'Généré', Color(0xFFD97706)),
  valide('valide', 'Validé', Color(0xFF16A34A)),
  verrouille('verrouille', 'Verrouillé', Color(0xFF1E3A8A));

  final String valeurApi;
  final String libelle;
  final Color couleur;

  const StatutBulletin(this.valeurApi, this.libelle, this.couleur);

  static StatutBulletin depuisApi(String valeur) => StatutBulletin.values.firstWhere(
        (s) => s.valeurApi == valeur,
        orElse: () => StatutBulletin.genere,
      );
}

// ══════════════════════════════════════════════════════════
// DecisionConseil
// ══════════════════════════════════════════════════════════
enum DecisionConseil {
  encouragements('encouragements', 'Encouragements'),
  felicitations('felicitations', 'Félicitations'),
  tableauHonneur('tableau_honneur', "Tableau d'honneur"),
  avertissementTravail('avertissement_travail', 'Avertissement travail'),
  avertissementConduite('avertissement_conduite', 'Avertissement conduite'),
  passage('passage', 'Admis(e) en classe supérieure'),
  redoublement('redoublement', 'Redouble la classe'),
  exclusion('exclusion', 'Exclusion');

  final String valeurApi;
  final String libelle;

  const DecisionConseil(this.valeurApi, this.libelle);

  static DecisionConseil? depuisApi(String? valeur) {
    if (valeur == null) return null;
    for (final d in DecisionConseil.values) {
      if (d.valeurApi == valeur) return d;
    }
    return null;
  }
}

double _versDouble(dynamic valeur) => double.parse((valeur ?? 0).toString());

double? _versDoubleNullable(dynamic valeur) => valeur == null ? null : double.tryParse(valeur.toString());

int _versEntier(dynamic valeur) => (valeur as num?)?.toInt() ?? 0;

// ══════════════════════════════════════════════════════════
// BulletinDetail — une ligne matière du bulletin (snapshot figé au moment
// de la génération : nom_matiere/coefficient ne bougent plus ensuite même
// si la matière source change).
// ══════════════════════════════════════════════════════════
class BulletinDetail {
  final int? id;
  final int? matiereId;
  final String nomMatiere;
  final double coefficient;
  final double note;
  final double? moyenneMatiereClasse;
  final String? appreciationMatiere;

  BulletinDetail({
    this.id,
    this.matiereId,
    required this.nomMatiere,
    required this.coefficient,
    required this.note,
    this.moyenneMatiereClasse,
    this.appreciationMatiere,
  });

  factory BulletinDetail.fromJson(Map<String, dynamic> json) {
    return BulletinDetail(
      id: json['id'] as int?,
      matiereId: json['matiere_id'] as int?,
      nomMatiere: json['nom_matiere'] as String? ?? '',
      coefficient: _versDouble(json['coefficient']),
      note: _versDouble(json['note']),
      moyenneMatiereClasse: _versDoubleNullable(json['moyenne_matiere_classe']),
      appreciationMatiere: json['appreciation_matiere'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'matiere_id': matiereId,
        'nom_matiere': nomMatiere,
        'coefficient': coefficient,
        'note': note,
        'moyenne_matiere_classe': moyenneMatiereClasse,
        'appreciation_matiere': appreciationMatiere,
      };
}

// ══════════════════════════════════════════════════════════
// Bulletin
// ══════════════════════════════════════════════════════════
class Bulletin {
  final int id;
  final int eleveId;
  final String? nomEleve;
  final String? matriculeEleve;
  final int classeId;
  final String? nomClasse;
  final int periodeId;
  final String? nomPeriode;
  final double moyenneGenerale;
  final int? rang;
  final bool rangExAequo;
  final int effectifClasse;
  final double totalCoefficients;
  final double totalPoints;
  final int absencesJustifiees;
  final int absencesNonJustifiees;
  final int retards;
  final DecisionConseil? decisionConseil;
  final String? appreciationGenerale;
  final StatutBulletin statut;
  final int? genereePar;
  final int? validePar;
  final DateTime? dateValidation;
  final int? professeurPrincipalId;
  final List<BulletinDetail> details;

  Bulletin({
    required this.id,
    required this.eleveId,
    this.nomEleve,
    this.matriculeEleve,
    required this.classeId,
    this.nomClasse,
    required this.periodeId,
    this.nomPeriode,
    required this.moyenneGenerale,
    this.rang,
    this.rangExAequo = false,
    required this.effectifClasse,
    required this.totalCoefficients,
    required this.totalPoints,
    this.absencesJustifiees = 0,
    this.absencesNonJustifiees = 0,
    this.retards = 0,
    this.decisionConseil,
    this.appreciationGenerale,
    this.statut = StatutBulletin.genere,
    this.genereePar,
    this.validePar,
    this.dateValidation,
    this.professeurPrincipalId,
    this.details = const [],
  });

  bool get estGenereNonValide => statut == StatutBulletin.genere;
  bool get estValideOuVerrouille => statut != StatutBulletin.genere;
  bool get estVerrouille => statut == StatutBulletin.verrouille;

  factory Bulletin.fromJson(Map<String, dynamic> json) {
    final eleve = json['eleve'] as Map<String, dynamic>?;
    final classe = json['classe'] as Map<String, dynamic>?;
    final periode = json['periode'] as Map<String, dynamic>?;

    return Bulletin(
      id: json['id'] as int,
      eleveId: json['eleve_id'] as int,
      nomEleve: eleve != null ? '${eleve['nom'] ?? ''} ${eleve['prenom'] ?? ''}'.trim() : null,
      matriculeEleve: eleve?['matricule'] as String?,
      classeId: json['classe_id'] as int,
      nomClasse: classe?['nom'] as String?,
      periodeId: json['periode_id'] as int,
      nomPeriode: periode?['nom'] as String?,
      moyenneGenerale: _versDouble(json['moyenne_generale']),
      rang: json['rang'] as int?,
      rangExAequo: json['rang_ex_aequo'] as bool? ?? false,
      effectifClasse: _versEntier(json['effectif_classe']),
      totalCoefficients: _versDouble(json['total_coefficients']),
      totalPoints: _versDouble(json['total_points']),
      absencesJustifiees: _versEntier(json['absences_justifiees']),
      absencesNonJustifiees: _versEntier(json['absences_non_justifiees']),
      retards: _versEntier(json['retards']),
      decisionConseil: DecisionConseil.depuisApi(json['decision_conseil'] as String?),
      appreciationGenerale: json['appreciation_generale'] as String?,
      statut: StatutBulletin.depuisApi(json['statut'] as String? ?? 'genere'),
      genereePar: json['genere_par'] as int?,
      validePar: json['valide_par'] as int?,
      dateValidation:
          json['date_validation'] != null ? DateTime.tryParse(json['date_validation'].toString()) : null,
      professeurPrincipalId: json['professeur_principal_id'] as int?,
      details: (json['details'] as List? ?? [])
          .map((d) => BulletinDetail.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'eleve_id': eleveId,
        'classe_id': classeId,
        'periode_id': periodeId,
        'moyenne_generale': moyenneGenerale,
        'rang': rang,
        'rang_ex_aequo': rangExAequo,
        'effectif_classe': effectifClasse,
        'total_coefficients': totalCoefficients,
        'total_points': totalPoints,
        'absences_justifiees': absencesJustifiees,
        'absences_non_justifiees': absencesNonJustifiees,
        'retards': retards,
        'decision_conseil': decisionConseil?.valeurApi,
        'appreciation_generale': appreciationGenerale,
        'statut': statut.valeurApi,
        'details': details.map((d) => d.toJson()).toList(),
      };
}

// ══════════════════════════════════════════════════════════
// StatutGenerationEleve — une ligne de GET /bulletins/generation/statut
// (dashboard "prêt à générer" avant de lancer la génération de classe)
// ══════════════════════════════════════════════════════════
class StatutGenerationEleve {
  final int eleveId;
  final String nom;
  final bool genere;
  final String? raisonBlocage;
  final int? bulletinId;
  final StatutBulletin? statutBulletin;

  StatutGenerationEleve({
    required this.eleveId,
    required this.nom,
    required this.genere,
    this.raisonBlocage,
    this.bulletinId,
    this.statutBulletin,
  });

  bool get estPret => genere || raisonBlocage == null;

  factory StatutGenerationEleve.fromJson(Map<String, dynamic> json) {
    return StatutGenerationEleve(
      eleveId: json['eleve_id'] as int,
      nom: '${json['nom'] ?? ''} ${json['prenom'] ?? ''}'.trim(),
      genere: json['genere'] as bool? ?? false,
      raisonBlocage: json['blocage'] as String?,
      bulletinId: json['bulletin_id'] as int?,
      statutBulletin:
          json['statut_bulletin'] != null ? StatutBulletin.depuisApi(json['statut_bulletin'] as String) : null,
    );
  }
}

// ══════════════════════════════════════════════════════════
// ResumeDashboardBulletin — GET /bulletins/dashboard/resume
// ══════════════════════════════════════════════════════════
class ResumeDashboardBulletin {
  final int anneeScolaireId;
  final int periodeId;
  final int effectifTotal;
  final int bulletinsGeneres;
  final int bulletinsValides;
  final int bulletinsEnAttente;
  final int classesConcernees;
  final int bulletinsNonGeneres;

  ResumeDashboardBulletin({
    required this.anneeScolaireId,
    required this.periodeId,
    required this.effectifTotal,
    required this.bulletinsGeneres,
    required this.bulletinsValides,
    required this.bulletinsEnAttente,
    required this.classesConcernees,
    required this.bulletinsNonGeneres,
  });

  factory ResumeDashboardBulletin.fromJson(Map<String, dynamic> json) {
    return ResumeDashboardBulletin(
      anneeScolaireId: json['annee_scolaire_id'] as int,
      periodeId: json['periode_id'] as int,
      effectifTotal: _versEntier(json['effectif_total']),
      bulletinsGeneres: _versEntier(json['nombre_bulletins_generes']),
      bulletinsValides: _versEntier(json['nombre_bulletins_valides']),
      bulletinsEnAttente: _versEntier(json['nombre_bulletins_en_attente']),
      classesConcernees: _versEntier(json['nombre_classes_concernees']),
      bulletinsNonGeneres: _versEntier(json['nombre_bulletins_non_generes']),
    );
  }
}

// ══════════════════════════════════════════════════════════
// EleveResultatGeneration / ResumeGenerationClasse — résumé
// réussis/échoués de POST /bulletins/generation/classe. Pas demandées
// nommément dans le brief mais indispensables pour que
// generation_bulletin_screen.dart puisse afficher ce résumé.
// ══════════════════════════════════════════════════════════
class EleveResultatGeneration {
  final int eleveId;
  final String nom;
  final int? bulletinId;
  final String? raison;

  EleveResultatGeneration({required this.eleveId, required this.nom, this.bulletinId, this.raison});

  factory EleveResultatGeneration.fromJson(Map<String, dynamic> json) {
    return EleveResultatGeneration(
      eleveId: json['eleve_id'] as int,
      nom: '${json['nom'] ?? ''} ${json['prenom'] ?? ''}'.trim(),
      bulletinId: json['bulletin_id'] as int?,
      raison: json['raison'] as String?,
    );
  }
}

class ResumeGenerationClasse {
  final int classeId;
  final int periodeId;
  final int totalEleves;
  final int nombreReussis;
  final int nombreEchecs;
  final List<EleveResultatGeneration> reussis;
  final List<EleveResultatGeneration> echecs;

  ResumeGenerationClasse({
    required this.classeId,
    required this.periodeId,
    required this.totalEleves,
    required this.nombreReussis,
    required this.nombreEchecs,
    required this.reussis,
    required this.echecs,
  });

  factory ResumeGenerationClasse.fromJson(Map<String, dynamic> json) {
    return ResumeGenerationClasse(
      classeId: json['classe_id'] as int,
      periodeId: json['periode_id'] as int,
      totalEleves: _versEntier(json['total_eleves']),
      nombreReussis: _versEntier(json['nombre_reussis']),
      nombreEchecs: _versEntier(json['nombre_echecs']),
      reussis: (json['reussis'] as List? ?? [])
          .map((e) => EleveResultatGeneration.fromJson(e as Map<String, dynamic>))
          .toList(),
      echecs: (json['echecs'] as List? ?? [])
          .map((e) => EleveResultatGeneration.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
