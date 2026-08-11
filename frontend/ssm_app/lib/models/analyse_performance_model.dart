import 'note_model.dart';

// Associe un rang (position dans la liste, déjà triée par le backend) à
// chaque élève d'une réponse eleves-faibles/eleves-excellents. Fonction
// top-level pour être réutilisable depuis ResumeAnalyse.fromJson et
// directement depuis ValidationNoteService.getElevesFaibles/Excellents.
List<EleveNiveau> elevesNiveauAvecRang(List json) {
  final resultat = <EleveNiveau>[];
  for (var i = 0; i < json.length; i++) {
    resultat.add(EleveNiveau.fromJson(json[i] as Map<String, dynamic>, i + 1));
  }
  return resultat;
}

// ══════════════════════════════════════════════════════════
// ClasseIncomplete
// ══════════════════════════════════════════════════════════
class ClasseIncomplete {
  final int classeId;
  final String nomClasse;
  final List<String> matieresManquantes;

  ClasseIncomplete({required this.classeId, required this.nomClasse, required this.matieresManquantes});

  factory ClasseIncomplete.fromJson(Map<String, dynamic> json) {
    return ClasseIncomplete(
      classeId: json['classe_id'] as int,
      nomClasse: json['classe_nom'] as String? ?? '',
      matieresManquantes: (json['matieres_incompletes'] as List? ?? [])
          .map((m) => m['matiere_nom'] as String)
          .toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════
// EnseignantRetard
//
// Le backend fournit un nombre de jours de retard (jours_de_retard), pas
// une date limite exacte — le champ "dateLimite" du brief est donc exposé
// sous le nom joursDeRetard, la donnée réellement disponible côté API.
// ══════════════════════════════════════════════════════════
class EnseignantRetard {
  final int? enseignantId;
  final String nom;
  final String matiere;
  final String classe;
  final double pourcentageCompletion;
  final int joursDeRetard;

  EnseignantRetard({
    this.enseignantId,
    required this.nom,
    required this.matiere,
    required this.classe,
    required this.pourcentageCompletion,
    required this.joursDeRetard,
  });

  factory EnseignantRetard.fromJson(Map<String, dynamic> json) {
    return EnseignantRetard(
      enseignantId: json['enseignant_id'] as int?,
      nom: json['enseignant_nom'] as String? ?? '',
      matiere: json['matiere_nom'] as String? ?? '',
      classe: json['classe_nom'] as String? ?? '',
      pourcentageCompletion: double.tryParse((json['pourcentage_completion'] ?? 0).toString()) ?? 0,
      joursDeRetard: (json['jours_de_retard'] as num?)?.toInt() ?? 0,
    );
  }
}

// ══════════════════════════════════════════════════════════
// EleveNiveau
//
// "rang" = position dans la liste déjà triée renvoyée par le backend
// (élèves faibles triés croissant, excellents triés décroissant), PAS un
// rang général officiel — cette donnée n'est pas exposée par les endpoints
// élèves-faibles/excellents. Pour un rang certifié, voir la fiche élève.
// ══════════════════════════════════════════════════════════
class EleveNiveau {
  final int? eleveId;
  final String nom;
  final String prenom;
  final String classe;
  final double moyenne;
  final int rang;

  EleveNiveau({
    this.eleveId,
    required this.nom,
    required this.prenom,
    required this.classe,
    required this.moyenne,
    required this.rang,
  });

  String get nomComplet => '$nom $prenom';

  factory EleveNiveau.fromJson(Map<String, dynamic> json, int rang) {
    return EleveNiveau(
      eleveId: json['eleve_id'] as int?,
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      classe: json['classe_nom'] as String? ?? '',
      moyenne: double.tryParse((json['moyenne_generale'] ?? 0).toString()) ?? 0,
      rang: rang,
    );
  }
}

// ══════════════════════════════════════════════════════════
// ClassementClasse
// ══════════════════════════════════════════════════════════
class ClassementClasse {
  final int? classeId;
  final String classe;
  final int? nombreEleves;
  final double tauxReussite;
  final double? moyenneGenerale;

  ClassementClasse({
    this.classeId,
    required this.classe,
    this.nombreEleves,
    required this.tauxReussite,
    this.moyenneGenerale,
  });

  factory ClassementClasse.fromJson(Map<String, dynamic> json) {
    return ClassementClasse(
      classeId: json['classe_id'] as int?,
      classe: json['classe_nom'] as String? ?? '',
      nombreEleves: json['nombre_eleves'] as int?,
      tauxReussite: double.tryParse((json['taux_reussite'] ?? 0).toString()) ?? 0,
      moyenneGenerale: json['moyenne_classe'] != null ? double.tryParse(json['moyenne_classe'].toString()) : null,
    );
  }
}

// ══════════════════════════════════════════════════════════
// MatiereNonValidee / ClasseMatieresNonValidees
//
// Non listées explicitement dans le brief, mais nécessaires : l'écran
// d'analyse a une section "Matières non validées" dédiée, adossée à
// l'endpoint GET /notes/analyse/matieres-non-validees.
// ══════════════════════════════════════════════════════════
class MatiereNonValidee {
  final int matiereId;
  final String matiereNom;
  final String enseignantNom;
  final String statut;

  MatiereNonValidee({
    required this.matiereId,
    required this.matiereNom,
    required this.enseignantNom,
    required this.statut,
  });

  factory MatiereNonValidee.fromJson(Map<String, dynamic> json) {
    return MatiereNonValidee(
      matiereId: json['matiere_id'] as int,
      matiereNom: json['matiere_nom'] as String? ?? '',
      enseignantNom: json['enseignant_nom'] as String? ?? '',
      statut: json['statut'] as String? ?? '',
    );
  }
}

class ClasseMatieresNonValidees {
  final int classeId;
  final String classeNom;
  final List<MatiereNonValidee> matieres;

  ClasseMatieresNonValidees({required this.classeId, required this.classeNom, required this.matieres});

  factory ClasseMatieresNonValidees.fromJson(Map<String, dynamic> json) {
    return ClasseMatieresNonValidees(
      classeId: json['classe_id'] as int,
      classeNom: json['classe_nom'] as String? ?? '',
      matieres:
          (json['matieres'] as List? ?? []).map((m) => MatiereNonValidee.fromJson(m as Map<String, dynamic>)).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ResumeAnalyse
//
// GET /notes/analyse/resume ne renvoie pas de section "matières non
// validées" (endpoint séparé) : matieresNonValidees reste vide ici et doit
// être chargé via ValidationNoteService.getMatieresNonValidees() si besoin.
// ══════════════════════════════════════════════════════════
class ResumeAnalyse {
  final List<ClasseIncomplete> classesIncompletes;
  final int nombreClassesIncompletes;
  final List<ClasseMatieresNonValidees> matieresNonValidees;
  final List<EnseignantRetard> enseignantsEnRetard;
  final int nombreEnseignantsEnRetard;
  final List<EleveNiveau> elevesFaibles;
  final int nombreElevesFaibles;
  final List<EleveNiveau> elevesExcellents;
  final int nombreElevesExcellents;
  final List<ClassementClasse> classementClasses;

  ResumeAnalyse({
    required this.classesIncompletes,
    required this.nombreClassesIncompletes,
    required this.matieresNonValidees,
    required this.enseignantsEnRetard,
    required this.nombreEnseignantsEnRetard,
    required this.elevesFaibles,
    required this.nombreElevesFaibles,
    required this.elevesExcellents,
    required this.nombreElevesExcellents,
    required this.classementClasses,
  });

  factory ResumeAnalyse.fromJson(Map<String, dynamic> json) {
    return ResumeAnalyse(
      classesIncompletes:
          (json['classes_incompletes'] as List? ?? []).map((c) => ClasseIncomplete.fromJson(c as Map<String, dynamic>)).toList(),
      nombreClassesIncompletes: (json['nombre_classes_incompletes'] as num?)?.toInt() ?? 0,
      matieresNonValidees: const [],
      enseignantsEnRetard: (json['enseignants_en_retard'] as List? ?? [])
          .map((e) => EnseignantRetard.fromJson(e as Map<String, dynamic>))
          .toList(),
      nombreEnseignantsEnRetard: (json['nombre_enseignants_en_retard'] as num?)?.toInt() ?? 0,
      elevesFaibles: elevesNiveauAvecRang(json['eleves_faibles'] as List? ?? []),
      nombreElevesFaibles: (json['nombre_eleves_faibles'] as num?)?.toInt() ?? 0,
      elevesExcellents: elevesNiveauAvecRang(json['eleves_excellents'] as List? ?? []),
      nombreElevesExcellents: (json['nombre_eleves_excellents'] as num?)?.toInt() ?? 0,
      classementClasses: (json['classement_classes'] as List? ?? [])
          .map((c) => ClassementClasse.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════
// SaisieEnAttenteValidation — item de GET /notes/validation/en-attente
// (non listée explicitement dans le brief, mais indispensable : c'est la
// donnée affichée par validation_notes_screen.dart).
// ══════════════════════════════════════════════════════════
class SaisieEnAttenteValidation {
  final int id;
  final int classeId;
  final String classeNom;
  final int matiereId;
  final String matiereNom;
  final int? enseignantId;
  final String enseignantNom;
  final DateTime? dateSoumission;
  final int nombreNotes;
  final double? moyenneClasse;
  final int nombreAnomalies;

  SaisieEnAttenteValidation({
    required this.id,
    required this.classeId,
    required this.classeNom,
    required this.matiereId,
    required this.matiereNom,
    this.enseignantId,
    required this.enseignantNom,
    this.dateSoumission,
    required this.nombreNotes,
    this.moyenneClasse,
    required this.nombreAnomalies,
  });

  factory SaisieEnAttenteValidation.fromJson(Map<String, dynamic> json) {
    return SaisieEnAttenteValidation(
      id: json['id'] as int,
      classeId: json['classe_id'] as int,
      classeNom: json['classe_nom'] as String? ?? '',
      matiereId: json['matiere_id'] as int,
      matiereNom: json['matiere_nom'] as String? ?? '',
      enseignantId: json['enseignant_id'] as int?,
      enseignantNom: json['enseignant_nom'] as String? ?? '',
      dateSoumission:
          json['date_soumission'] != null ? DateTime.tryParse(json['date_soumission'].toString()) : null,
      nombreNotes: (json['nombre_notes'] as num?)?.toInt() ?? 0,
      moyenneClasse: json['moyenne_classe'] != null ? double.tryParse(json['moyenne_classe'].toString()) : null,
      nombreAnomalies: (json['nombre_anomalies'] as num?)?.toInt() ?? 0,
    );
  }
}

// ══════════════════════════════════════════════════════════
// DetailSaisieValidation — réponse de GET /notes/validation/{id}
// Réutilise SaisieNote / EleveSaisie / Note / StatistiquesSaisie de
// note_model.dart plutôt que de dupliquer des classes déjà écrites pour le
// même usage (tableau élève → notes devoir/composition).
// ══════════════════════════════════════════════════════════
class DetailSaisieValidation {
  final SaisieNote saisie;
  // SaisieNote.fromJson ne lit pas la relation "enseignant" (non nécessaire
  // ailleurs) : nom extrait ici directement depuis le JSON brut.
  final String enseignantNom;
  final List<EleveSaisie> eleves;
  final StatistiquesSaisie statistiques;

  DetailSaisieValidation({
    required this.saisie,
    required this.enseignantNom,
    required this.eleves,
    required this.statistiques,
  });

  factory DetailSaisieValidation.fromJson(Map<String, dynamic> json) {
    final saisieJson = json['saisie'] as Map<String, dynamic>;
    final enseignant = saisieJson['enseignant'] as Map<String, dynamic>?;

    return DetailSaisieValidation(
      saisie: SaisieNote.fromJson(saisieJson),
      enseignantNom: enseignant?['name'] as String? ?? '',
      eleves: _regrouperParEleve(json['notes'] as List? ?? []),
      statistiques: StatistiquesSaisie.fromJson(json['statistiques'] as Map<String, dynamic>? ?? {}),
    );
  }

  static List<EleveSaisie> _regrouperParEleve(List notesJson) {
    final parEleve = <int, Map<String, dynamic>>{};

    for (final n in notesJson) {
      final noteJson = n as Map<String, dynamic>;
      final eleveJson = noteJson['eleve'] as Map<String, dynamic>?;
      final eleveId = noteJson['eleve_id'] as int;

      parEleve.putIfAbsent(eleveId, () => {
            'eleve_id': eleveId,
            'nom': eleveJson?['nom'] as String? ?? '',
            'prenom': eleveJson?['prenom'] as String? ?? '',
            'matricule': eleveJson?['matricule'] as String?,
          });

      final note = Note.fromJson(noteJson);
      if (note.typeEvaluation == TypeEvaluation.devoir) {
        parEleve[eleveId]!['devoir'] = note;
      } else {
        parEleve[eleveId]!['composition'] = note;
      }
    }

    final resultat = parEleve.values
        .map((e) => EleveSaisie(
              eleveId: e['eleve_id'] as int,
              nom: e['nom'] as String,
              prenom: e['prenom'] as String,
              matricule: e['matricule'] as String?,
              noteDevoir: e['devoir'] as Note?,
              noteComposition: e['composition'] as Note?,
            ))
        .toList();

    resultat.sort((a, b) => a.nom.compareTo(b.nom));
    return resultat;
  }
}
