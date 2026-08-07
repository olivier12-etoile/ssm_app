import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════
// Enum ModePaiement
// ══════════════════════════════════════════════════════════
enum ModePaiement {
  especes('especes', 'Espèces', Icons.payments_outlined),
  moovMoney('moov_money', 'Moov Money', Icons.phone_android),
  wave('wave', 'Wave', Icons.waves),
  virement('virement', 'Virement', Icons.account_balance_outlined),
  cheque('cheque', 'Chèque', Icons.receipt_long_outlined);

  final String valeurApi;
  final String libelle;
  final IconData icone;

  const ModePaiement(this.valeurApi, this.libelle, this.icone);

  static ModePaiement depuisApi(String valeur) => ModePaiement.values.firstWhere(
        (m) => m.valeurApi == valeur,
        orElse: () => ModePaiement.especes,
      );
}

// ══════════════════════════════════════════════════════════
// Paiement
// ══════════════════════════════════════════════════════════
class Paiement {
  final int? id;
  final int eleveId;
  final int fraisScolaireId;
  final int? echeanceId;
  final double montant;
  final ModePaiement modePaiement;
  final String? reference;
  final DateTime datePaiement;
  final String? observation;
  final String? numeroRecu;
  final String statut; // 'valide' | 'annule'
  final String? motifAnnulation;
  final int? createdBy;

  // Champs de confort issus des relations chargées côté API
  // (frais_scolaire, echeance, eleve, cree_par) — nullable car
  // pas toujours présents selon l'endpoint appelé.
  final String? fraisNom;
  final String? echeanceLibelle;
  final String? eleveNom;
  final String? elevePrenom;
  final String? creeParNom;

  Paiement({
    this.id,
    required this.eleveId,
    required this.fraisScolaireId,
    this.echeanceId,
    required this.montant,
    required this.modePaiement,
    this.reference,
    required this.datePaiement,
    this.observation,
    this.numeroRecu,
    this.statut = 'valide',
    this.motifAnnulation,
    this.createdBy,
    this.fraisNom,
    this.echeanceLibelle,
    this.eleveNom,
    this.elevePrenom,
    this.creeParNom,
  });

  bool get estAnnule => statut == 'annule';

  factory Paiement.fromJson(Map<String, dynamic> json) {
    final fraisScolaire = json['frais_scolaire'] as Map<String, dynamic>?;
    final echeance = json['echeance'] as Map<String, dynamic>?;
    final eleve = json['eleve'] as Map<String, dynamic>?;
    final creePar = json['cree_par'] as Map<String, dynamic>?;

    return Paiement(
      id: json['id'] as int?,
      eleveId: json['eleve_id'] as int,
      fraisScolaireId: json['frais_scolaire_id'] as int,
      echeanceId: json['echeance_id'] as int?,
      montant: double.parse(json['montant'].toString()),
      modePaiement: ModePaiement.depuisApi(json['mode_paiement'] as String),
      reference: json['reference'] as String?,
      datePaiement: DateTime.parse(json['date_paiement'] as String),
      observation: json['observation'] as String?,
      numeroRecu: json['numero_recu'] as String?,
      statut: json['statut'] as String? ?? 'valide',
      motifAnnulation: json['motif_annulation'] as String?,
      createdBy: json['created_by'] as int?,
      fraisNom: fraisScolaire?['nom'] as String?,
      echeanceLibelle: echeance?['libelle'] as String?,
      eleveNom: eleve?['nom'] as String?,
      elevePrenom: eleve?['prenom'] as String?,
      creeParNom: creePar?['name'] as String?,
    );
  }

  // Corps de requête pour l'enregistrement d'un nouveau paiement
  // (POST /paiements) — les champs calculés côté serveur (numero_recu,
  // statut, created_by...) ne sont pas envoyés.
  Map<String, dynamic> toJsonCreation() {
    return {
      'eleve_id': eleveId,
      'frais_scolaire_id': fraisScolaireId,
      'echeance_id': echeanceId,
      'montant': montant,
      'mode_paiement': modePaiement.valeurApi,
      'reference': reference,
      'date_paiement': '${datePaiement.year.toString().padLeft(4, '0')}-'
          '${datePaiement.month.toString().padLeft(2, '0')}-'
          '${datePaiement.day.toString().padLeft(2, '0')}',
      'observation': observation,
    };
  }
}

// ══════════════════════════════════════════════════════════
// DetailFrais — situation d'un élève sur un frais donné
// ══════════════════════════════════════════════════════════
class DetailFrais {
  final int fraisScolaireId;
  final String nomFrais;
  final double montant;
  final DateTime? dateLimite;
  final double montantDu;
  final double montantPaye;
  final double reste;
  final String statut; // 'paye' | 'partiel' | 'impaye'

  DetailFrais({
    required this.fraisScolaireId,
    required this.nomFrais,
    required this.montant,
    this.dateLimite,
    required this.montantDu,
    required this.montantPaye,
    required this.reste,
    required this.statut,
  });

  factory DetailFrais.fromJson(Map<String, dynamic> json) {
    return DetailFrais(
      fraisScolaireId: json['frais_scolaire_id'] as int,
      nomFrais: json['nom'] as String,
      montant: double.parse(json['montant'].toString()),
      dateLimite: json['date_limite'] != null
          ? DateTime.tryParse(json['date_limite'].toString())
          : null,
      montantDu: double.parse(json['montant_du'].toString()),
      montantPaye: double.parse(json['montant_paye'].toString()),
      reste: double.parse(json['reste_a_payer'].toString()),
      statut: json['statut'] as String,
    );
  }

  double get progression => montantDu > 0 ? (montantPaye / montantDu).clamp(0.0, 1.0) : 1.0;
}

// ══════════════════════════════════════════════════════════
// SituationFinanciere — vue d'ensemble pour un élève
// ══════════════════════════════════════════════════════════
class SituationFinanciere {
  final int eleveId;
  final String eleveNom;
  final String elevePrenom;
  final String? matricule;
  final double montantAttendu;
  final double montantPaye;
  final double resteAPayer;
  final List<DetailFrais> detailParFrais;
  final List<Paiement> historique;

  SituationFinanciere({
    required this.eleveId,
    required this.eleveNom,
    required this.elevePrenom,
    this.matricule,
    required this.montantAttendu,
    required this.montantPaye,
    required this.resteAPayer,
    required this.detailParFrais,
    required this.historique,
  });

  factory SituationFinanciere.fromJson(Map<String, dynamic> json) {
    final eleve = json['eleve'] as Map<String, dynamic>?;
    return SituationFinanciere(
      eleveId: eleve?['id'] as int? ?? 0,
      eleveNom: eleve?['nom'] as String? ?? '',
      elevePrenom: eleve?['prenom'] as String? ?? '',
      matricule: eleve?['matricule'] as String?,
      montantAttendu: double.parse(json['montant_attendu'].toString()),
      montantPaye: double.parse(json['montant_paye'].toString()),
      resteAPayer: double.parse(json['reste_a_payer'].toString()),
      detailParFrais: (json['frais'] as List? ?? [])
          .map((f) => DetailFrais.fromJson(f as Map<String, dynamic>))
          .toList(),
      historique: (json['historique_paiements'] as List? ?? [])
          .map((p) => Paiement.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  // 'a_jour' | 'partiel' | 'aucun_paiement'
  String get statutGlobal {
    if (resteAPayer <= 0) return 'a_jour';
    if (montantPaye > 0) return 'partiel';
    return 'aucun_paiement';
  }

  DetailFrais? detailPourFrais(int fraisScolaireId) {
    for (final d in detailParFrais) {
      if (d.fraisScolaireId == fraisScolaireId) return d;
    }
    return null;
  }
}
