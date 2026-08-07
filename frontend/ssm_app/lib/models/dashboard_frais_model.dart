// ══════════════════════════════════════════════════════════
// PointMensuel — un point de la courbe d'évolution des recettes
// ══════════════════════════════════════════════════════════
class PointMensuel {
  final String mois; // libellé français, ex: "Janvier 2026"
  final double montant;

  PointMensuel({required this.mois, required this.montant});

  factory PointMensuel.fromJson(Map<String, dynamic> json) {
    return PointMensuel(
      mois: (json['libelle'] ?? json['mois']).toString(),
      montant: double.parse(json['montant'].toString()),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ResumeFinancier — résumé du tableau de bord (année active)
// ══════════════════════════════════════════════════════════
class ResumeFinancier {
  final String? anneeLibelle;
  final double montantAttendu;
  final double montantEncaisse;
  final double montantRestant;
  final int nombreAJour;
  final int nombrePartiel;
  final int nombreAucunPaiement;
  final double tauxRecouvrement;
  final List<PointMensuel> evolutionMensuelle;

  ResumeFinancier({
    this.anneeLibelle,
    required this.montantAttendu,
    required this.montantEncaisse,
    required this.montantRestant,
    required this.nombreAJour,
    required this.nombrePartiel,
    required this.nombreAucunPaiement,
    required this.tauxRecouvrement,
    required this.evolutionMensuelle,
  });

  factory ResumeFinancier.fromJson(Map<String, dynamic> json) {
    return ResumeFinancier(
      anneeLibelle: json['annee_libelle'] as String?,
      montantAttendu: double.parse(json['montant_attendu'].toString()),
      montantEncaisse: double.parse(json['montant_encaisse'].toString()),
      montantRestant: double.parse(json['montant_restant'].toString()),
      nombreAJour: (json['nombre_eleves_a_jour'] as num?)?.toInt() ?? 0,
      nombrePartiel: (json['nombre_eleves_partiel'] as num?)?.toInt() ?? 0,
      nombreAucunPaiement: (json['nombre_eleves_aucun_paiement'] as num?)?.toInt() ?? 0,
      tauxRecouvrement: double.parse((json['taux_recouvrement'] ?? 0).toString()),
      evolutionMensuelle: (json['evolution_mensuelle'] as List? ?? [])
          .map((e) => PointMensuel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════
// EleveDebiteur — un élève avec un reste à payer
// ══════════════════════════════════════════════════════════
class EleveDebiteur {
  final int eleveId;
  final String nom;
  final String prenom;
  final String? matricule;
  final int? classeId;
  final String classe;
  final double montantAttendu;
  final double montantPaye;
  final double montantRestant;
  final double pourcentageImpaye;
  final int joursRetard;
  final String? telephoneParent;

  EleveDebiteur({
    required this.eleveId,
    required this.nom,
    required this.prenom,
    this.matricule,
    this.classeId,
    required this.classe,
    required this.montantAttendu,
    required this.montantPaye,
    required this.montantRestant,
    required this.pourcentageImpaye,
    required this.joursRetard,
    this.telephoneParent,
  });

  String get nomComplet => '$nom $prenom';

  factory EleveDebiteur.fromJson(Map<String, dynamic> json) {
    return EleveDebiteur(
      eleveId: json['eleve_id'] as int,
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      matricule: json['matricule'] as String?,
      classeId: json['classe_id'] as int?,
      classe: json['classe_nom'] as String? ?? 'Non affecté',
      montantAttendu: double.parse((json['montant_attendu'] ?? 0).toString()),
      montantPaye: double.parse((json['montant_paye'] ?? 0).toString()),
      montantRestant: double.parse((json['montant_restant'] ?? 0).toString()),
      pourcentageImpaye: double.parse((json['pourcentage_impaye'] ?? 0).toString()),
      joursRetard: (json['jours_de_retard'] as num?)?.toInt() ?? 0,
      telephoneParent: json['telephone_parent'] as String?,
    );
  }
}

// ══════════════════════════════════════════════════════════
// SerieGraphique — {labels, valeurs} générique pour fl_chart
// ══════════════════════════════════════════════════════════
class SerieGraphique {
  final List<String> labels;
  final List<double> valeurs;

  SerieGraphique({required this.labels, required this.valeurs});

  factory SerieGraphique.fromJson(Map<String, dynamic> json) {
    return SerieGraphique(
      labels: (json['labels'] as List? ?? []).map((e) => e.toString()).toList(),
      valeurs: (json['valeurs'] as List? ?? [])
          .map((e) => double.parse(e.toString()))
          .toList(),
    );
  }

  bool get estVide => labels.isEmpty;
}

// ══════════════════════════════════════════════════════════
// ClasseTaux — taux de recouvrement d'une classe (top classes)
// ══════════════════════════════════════════════════════════
class ClasseTaux {
  final int? classeId;
  final String classeNom;
  final double attendu;
  final double encaisse;
  final double taux;

  ClasseTaux({
    this.classeId,
    required this.classeNom,
    required this.attendu,
    required this.encaisse,
    required this.taux,
  });

  factory ClasseTaux.fromJson(Map<String, dynamic> json) {
    return ClasseTaux(
      classeId: json['classe_id'] as int?,
      classeNom: json['classe_nom'] as String? ?? 'Non affecté',
      attendu: double.parse((json['attendu'] ?? 0).toString()),
      encaisse: double.parse((json['encaisse'] ?? 0).toString()),
      taux: double.parse((json['taux'] ?? 0).toString()),
    );
  }
}

// ══════════════════════════════════════════════════════════
// StatistiquesFrais — graphiques du module Frais Scolaires
// ══════════════════════════════════════════════════════════
class StatistiquesFrais {
  final SerieGraphique recettesParMois;
  final SerieGraphique recettesParClasse;
  final SerieGraphique recettesParNiveau;
  final List<ClasseTaux> topClassesAJour;
  final List<ClasseTaux> topClassesRetard;

  StatistiquesFrais({
    required this.recettesParMois,
    required this.recettesParClasse,
    required this.recettesParNiveau,
    required this.topClassesAJour,
    required this.topClassesRetard,
  });

  factory StatistiquesFrais.fromJson(Map<String, dynamic> json) {
    return StatistiquesFrais(
      recettesParMois: SerieGraphique.fromJson(json['recettes_par_mois'] as Map<String, dynamic>? ?? {}),
      recettesParClasse: SerieGraphique.fromJson(json['recettes_par_classe'] as Map<String, dynamic>? ?? {}),
      recettesParNiveau: SerieGraphique.fromJson(json['recettes_par_niveau'] as Map<String, dynamic>? ?? {}),
      topClassesAJour: (json['top_classes_a_jour'] as List? ?? [])
          .map((e) => ClasseTaux.fromJson(e as Map<String, dynamic>))
          .toList(),
      topClassesRetard: (json['top_classes_retard'] as List? ?? [])
          .map((e) => ClasseTaux.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
