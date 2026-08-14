import 'package:flutter/material.dart';

// ── Aides internes de parsing ──────────────────────────────
// Certaines relations Laravel (ouvertPar, fermePar, corrigePar) se
// sérialisent en JSON avec exactement la même clé snake_case que la colonne
// FK qu'elles décorent (ouvert_par, ferme_par, corrige_par) : selon que la
// relation a été chargée côté API, cette clé contient donc soit un entier
// (id brut), soit un objet utilisateur {id, name, ...}. On gère les deux.
int? _idDepuis(dynamic valeur) {
  if (valeur == null) return null;
  if (valeur is int) return valeur;
  if (valeur is Map) return valeur['id'] as int?;
  return null;
}

String? _nomDepuis(dynamic valeur) {
  if (valeur is Map) return valeur['name'] as String? ?? valeur['nom'] as String?;
  return null;
}

double? _doubleNullableDepuis(dynamic valeur) =>
    valeur == null ? null : double.parse(valeur.toString());

// ══════════════════════════════════════════════════════════
// Caisse
// ══════════════════════════════════════════════════════════
class Caisse {
  final int? id;
  final String nom;
  final bool actif;

  Caisse({this.id, required this.nom, this.actif = true});

  factory Caisse.fromJson(Map<String, dynamic> json) {
    return Caisse(
      id: json['id'] as int?,
      nom: json['nom'] as String,
      actif: json['actif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {'nom': nom, 'actif': actif};
}

// ══════════════════════════════════════════════════════════
// SessionCaisse (ouverture/fermeture)
// ══════════════════════════════════════════════════════════
class SessionCaisse {
  final int? id;
  final int caisseId;
  final String? caisseNom;
  final int ouvertPar;
  final String? ouvertParNom;
  final double montantInitial;
  final DateTime dateOuverture;
  final int? fermePar;
  final String? fermeParNom;
  final DateTime? dateFermeture;
  final double? montantTheorique;
  final double? montantReel;
  final double? ecart;
  final String? observationFermeture;
  final String statut; // 'ouverte' | 'fermee'

  SessionCaisse({
    this.id,
    required this.caisseId,
    this.caisseNom,
    required this.ouvertPar,
    this.ouvertParNom,
    required this.montantInitial,
    required this.dateOuverture,
    this.fermePar,
    this.fermeParNom,
    this.dateFermeture,
    this.montantTheorique,
    this.montantReel,
    this.ecart,
    this.observationFermeture,
    this.statut = 'ouverte',
  });

  bool get estOuverte => statut == 'ouverte';

  factory SessionCaisse.fromJson(Map<String, dynamic> json) {
    final caisse = json['caisse'] as Map<String, dynamic>?;

    return SessionCaisse(
      id: json['id'] as int?,
      caisseId: json['caisse_id'] as int,
      caisseNom: caisse?['nom'] as String?,
      ouvertPar: _idDepuis(json['ouvert_par']) ?? 0,
      ouvertParNom: _nomDepuis(json['ouvert_par']),
      montantInitial: double.parse(json['montant_initial'].toString()),
      dateOuverture: DateTime.parse(json['date_ouverture'] as String),
      fermePar: _idDepuis(json['ferme_par']),
      fermeParNom: _nomDepuis(json['ferme_par']),
      dateFermeture: json['date_fermeture'] != null
          ? DateTime.tryParse(json['date_fermeture'].toString())
          : null,
      montantTheorique: _doubleNullableDepuis(json['montant_theorique']),
      montantReel: _doubleNullableDepuis(json['montant_reel']),
      ecart: _doubleNullableDepuis(json['ecart']),
      observationFermeture: json['observation_fermeture'] as String?,
      statut: json['statut'] as String? ?? 'ouverte',
    );
  }
}

// ══════════════════════════════════════════════════════════
// StatutFinancier — badge de situation financière d'un élève
// ══════════════════════════════════════════════════════════
enum StatutFinancier {
  enRegle('en_regle', 'En règle', Color(0xFF16A34A), '🟢', Icons.check_circle),
  partiel('partiel', 'Partiel', Color(0xFFD97706), '🟠', Icons.donut_small),
  nonRegle('non_regle', 'Non réglé', Color(0xFFDC2626), '🔴', Icons.cancel),
  enRetard('en_retard', 'En retard', Color(0xFF991B1B), '⚠️', Icons.warning_amber_rounded);

  final String valeurApi;
  final String libelle;
  final Color couleur;
  final String emoji;
  final IconData icone;

  const StatutFinancier(this.valeurApi, this.libelle, this.couleur, this.emoji, this.icone);

  static StatutFinancier depuisApi(String valeur) => StatutFinancier.values.firstWhere(
        (s) => s.valeurApi == valeur,
        orElse: () => StatutFinancier.nonRegle,
      );
}

// Réponse complète de GET /paiements/eleves/{id}/statut-financier.
class EcheanceEnRetard {
  final int fraisScolaireId;
  final String fraisNom;
  final int? echeanceId;
  final String libelle;
  final DateTime dateLimite;
  final double resteAPayer;

  EcheanceEnRetard({
    required this.fraisScolaireId,
    required this.fraisNom,
    this.echeanceId,
    required this.libelle,
    required this.dateLimite,
    required this.resteAPayer,
  });

  factory EcheanceEnRetard.fromJson(Map<String, dynamic> json) {
    return EcheanceEnRetard(
      fraisScolaireId: json['frais_scolaire_id'] as int,
      fraisNom: json['frais_nom'] as String,
      echeanceId: json['echeance_id'] as int?,
      libelle: json['libelle'] as String,
      dateLimite: DateTime.parse(json['date_limite'] as String),
      resteAPayer: double.parse(json['reste_a_payer'].toString()),
    );
  }
}

class StatutFinancierEleve {
  final StatutFinancier statut;
  final double montantDu;
  final double montantPaye;
  final double resteAPayer;
  final List<EcheanceEnRetard> echeancesEnRetard;

  StatutFinancierEleve({
    required this.statut,
    required this.montantDu,
    required this.montantPaye,
    required this.resteAPayer,
    required this.echeancesEnRetard,
  });

  factory StatutFinancierEleve.fromJson(Map<String, dynamic> json) {
    return StatutFinancierEleve(
      statut: StatutFinancier.depuisApi(json['statut'] as String),
      montantDu: double.parse(json['montant_du'].toString()),
      montantPaye: double.parse(json['montant_paye'].toString()),
      resteAPayer: double.parse(json['reste_a_payer'].toString()),
      echeancesEnRetard: (json['echeances_en_retard'] as List? ?? [])
          .map((e) => EcheanceEnRetard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Correction — historique d'une correction de paiement
// ══════════════════════════════════════════════════════════
class Correction {
  final int? id;
  final int paiementId;
  final int corrigePar;
  final String? corrigeParNom;
  final double ancienMontant;
  final double nouveauMontant;
  final String? ancienModePaiement;
  final String? nouveauModePaiement;
  final String motif;
  final DateTime? createdAt;

  Correction({
    this.id,
    required this.paiementId,
    required this.corrigePar,
    this.corrigeParNom,
    required this.ancienMontant,
    required this.nouveauMontant,
    this.ancienModePaiement,
    this.nouveauModePaiement,
    required this.motif,
    this.createdAt,
  });

  factory Correction.fromJson(Map<String, dynamic> json) {
    return Correction(
      id: json['id'] as int?,
      paiementId: json['paiement_id'] as int,
      corrigePar: _idDepuis(json['corrige_par']) ?? 0,
      corrigeParNom: _nomDepuis(json['corrige_par']),
      ancienMontant: double.parse(json['ancien_montant'].toString()),
      nouveauMontant: double.parse(json['nouveau_montant'].toString()),
      ancienModePaiement: json['ancien_mode_paiement'] as String?,
      nouveauModePaiement: json['nouveau_mode_paiement'] as String?,
      motif: json['motif'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
