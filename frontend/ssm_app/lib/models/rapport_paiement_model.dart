// ══════════════════════════════════════════════════════════
// SituationClasse — agrégat GET /paiements/situation-classe[/{id}]
// ══════════════════════════════════════════════════════════
class SituationClasse {
  final int classeId;
  final String nomClasse;
  final int? anneeScolaireId;
  final int totalEleves;
  final int nombreEnRegle;
  final int nombrePartiels;
  final int nombreNonRegles;
  final int nombreEnRetard;
  final double montantAttendu;
  final double montantEncaisse;
  final double resteARecouvrer;
  final double tauxRecouvrement;

  SituationClasse({
    required this.classeId,
    required this.nomClasse,
    this.anneeScolaireId,
    required this.totalEleves,
    required this.nombreEnRegle,
    required this.nombrePartiels,
    required this.nombreNonRegles,
    required this.nombreEnRetard,
    required this.montantAttendu,
    required this.montantEncaisse,
    required this.resteARecouvrer,
    required this.tauxRecouvrement,
  });

  factory SituationClasse.fromJson(Map<String, dynamic> json) {
    return SituationClasse(
      classeId: json['classe_id'] as int,
      nomClasse: json['classe_nom'] as String? ?? 'Non affecté',
      anneeScolaireId: json['annee_scolaire_id'] as int?,
      totalEleves: (json['nombre_eleves'] as num?)?.toInt() ?? 0,
      nombreEnRegle: (json['nombre_en_regle'] as num?)?.toInt() ?? 0,
      nombrePartiels: (json['nombre_partiel'] as num?)?.toInt() ?? 0,
      nombreNonRegles: (json['nombre_non_regle'] as num?)?.toInt() ?? 0,
      nombreEnRetard: (json['nombre_en_retard'] as num?)?.toInt() ?? 0,
      montantAttendu: double.parse((json['montant_attendu'] ?? 0).toString()),
      montantEncaisse: double.parse((json['montant_encaisse'] ?? 0).toString()),
      resteARecouvrer: double.parse((json['reste_a_recouvrer'] ?? 0).toString()),
      tauxRecouvrement: double.parse((json['taux_recouvrement'] ?? 0).toString()),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ImpayeClasse — un élève non en règle d'une classe
// ══════════════════════════════════════════════════════════
class ImpayeClasse {
  final int eleveId;
  final String nom;
  final String prenom;
  final String? matricule;
  final double resteAPayer;
  final double montantAttendu;
  final double montantPaye;
  final String? telephoneParent;

  ImpayeClasse({
    required this.eleveId,
    required this.nom,
    required this.prenom,
    this.matricule,
    required this.resteAPayer,
    required this.montantAttendu,
    required this.montantPaye,
    this.telephoneParent,
  });

  String get nomComplet => '$nom $prenom';

  factory ImpayeClasse.fromJson(Map<String, dynamic> json) {
    return ImpayeClasse(
      eleveId: json['eleve_id'] as int,
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      matricule: json['matricule'] as String?,
      resteAPayer: double.parse((json['reste_a_payer'] ?? 0).toString()),
      montantAttendu: double.parse((json['montant_attendu'] ?? 0).toString()),
      montantPaye: double.parse((json['montant_paye'] ?? 0).toString()),
      telephoneParent: json['telephone_parent'] as String?,
    );
  }
}

// ══════════════════════════════════════════════════════════
// TransactionResume — une ligne du détail d'un rapport journalier
// ══════════════════════════════════════════════════════════
class TransactionResume {
  final String? numeroRecu;
  final String eleve;
  final String? classe;
  final String? fraisNom;
  final double montant;
  final String mode;
  final String date;

  TransactionResume({
    this.numeroRecu,
    required this.eleve,
    this.classe,
    this.fraisNom,
    required this.montant,
    required this.mode,
    required this.date,
  });

  factory TransactionResume.fromJson(Map<String, dynamic> json) {
    return TransactionResume(
      numeroRecu: json['numero_recu'] as String?,
      eleve: json['eleve'] as String? ?? '',
      classe: json['classe'] as String?,
      fraisNom: json['frais_nom'] as String?,
      montant: double.parse((json['montant'] ?? 0).toString()),
      mode: json['mode_paiement'] as String? ?? '',
      date: json['date_paiement'] as String? ?? '',
    );
  }
}

// ══════════════════════════════════════════════════════════
// PointJour / PointMoisRapport — détails optionnels selon le type
// de rapport (hebdomadaire → par_jour, annuel → evolution_mensuelle).
// ══════════════════════════════════════════════════════════
class PointJour {
  final String libelle;
  final int nombrePaiements;
  final double totalEncaisse;

  PointJour({required this.libelle, required this.nombrePaiements, required this.totalEncaisse});

  factory PointJour.fromJson(Map<String, dynamic> json) {
    return PointJour(
      libelle: json['libelle'] as String? ?? '',
      nombrePaiements: (json['nombre_paiements'] as num?)?.toInt() ?? 0,
      totalEncaisse: double.parse((json['total_encaisse'] ?? 0).toString()),
    );
  }
}

class PointMoisRapport {
  final String libelle;
  final double montant;

  PointMoisRapport({required this.libelle, required this.montant});

  factory PointMoisRapport.fromJson(Map<String, dynamic> json) {
    return PointMoisRapport(
      libelle: json['libelle'] as String? ?? '',
      montant: double.parse((json['montant'] ?? 0).toString()),
    );
  }
}

// ══════════════════════════════════════════════════════════
// RapportPaiement — réponse unifiée des 5 types de rapport
// (journalier/hebdomadaire/mensuel/annuel/personnalisé).
// Selon le type, seuls certains champs optionnels sont renseignés
// par l'API (ex. transactions détaillées uniquement pour "journalier").
// ══════════════════════════════════════════════════════════
class RapportPaiement {
  final String typeRapport;
  final String periode;
  final int nombrePaiements;
  final double totalEncaisse;
  final Map<String, double> ventilationParMode;
  final Map<String, double> ventilationParClasse;
  final List<TransactionResume> transactions;

  // Champs additionnels — présents seulement pour certains types de
  // rapport, mais réellement renvoyés par l'API : on les conserve plutôt
  // que de les perdre silencieusement.
  final double? montantAttendu;
  final double? resteARecouvrer;
  final List<PointJour> parJour;
  final List<PointMoisRapport> evolutionMensuelle;

  RapportPaiement({
    required this.typeRapport,
    required this.periode,
    required this.nombrePaiements,
    required this.totalEncaisse,
    required this.ventilationParMode,
    required this.ventilationParClasse,
    required this.transactions,
    this.montantAttendu,
    this.resteARecouvrer,
    this.parJour = const [],
    this.evolutionMensuelle = const [],
  });

  factory RapportPaiement.fromJson(String typeRapport, Map<String, dynamic> json) {
    final parMode = (json['par_mode_paiement'] as List? ?? [])
        .map((m) => m as Map<String, dynamic>)
        .fold<Map<String, double>>({}, (acc, m) {
      acc[m['libelle'] as String? ?? m['mode'] as String? ?? '?'] =
          double.parse((m['montant'] ?? 0).toString());
      return acc;
    });

    final parClasse = (json['par_classe'] as List? ?? [])
        .map((c) => c as Map<String, dynamic>)
        .fold<Map<String, double>>({}, (acc, c) {
      acc[c['classe_nom'] as String? ?? 'Non affecté'] = double.parse((c['montant'] ?? 0).toString());
      return acc;
    });

    return RapportPaiement(
      typeRapport: typeRapport,
      periode: (json['periode_libelle'] ?? json['date'] ?? '').toString(),
      nombrePaiements: (json['nombre_paiements'] as num?)?.toInt() ?? 0,
      totalEncaisse: double.parse((json['total_encaisse'] ?? json['total_encaisse_periode'] ?? 0).toString()),
      ventilationParMode: parMode,
      ventilationParClasse: parClasse,
      transactions: (json['transactions'] as List? ?? [])
          .map((t) => TransactionResume.fromJson(t as Map<String, dynamic>))
          .toList(),
      montantAttendu: json['montant_attendu'] != null ? double.parse(json['montant_attendu'].toString()) : null,
      resteARecouvrer: json['reste_a_recouvrer'] != null ? double.parse(json['reste_a_recouvrer'].toString()) : null,
      parJour: (json['par_jour'] as List? ?? [])
          .map((j) => PointJour.fromJson(j as Map<String, dynamic>))
          .toList(),
      evolutionMensuelle: (json['evolution_mensuelle'] as List? ?? [])
          .map((m) => PointMoisRapport.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
