// Modèles du module Paramètres de l'École (sections Établissement,
// Direction, Identité visuelle, Scolarité, Finance, Notifications).
// Les clés JSON reprennent celles de l'API Laravel (voir
// backend/app/Http/Controllers/Api/Parametre*Controller.php).

// ══════════════════════════════════════════════════════════
// Établissement — GET/PUT /parametres/etablissement
// ══════════════════════════════════════════════════════════
class InformationsEtablissement {
  final String? nomOfficiel;
  final String? nomCourt;
  final String? sigle;
  final String? codeEcole;
  final String? type;
  final String? adresse;
  final String? ville;
  final String? region;
  final String? pays;
  final String? telephone;
  final String? email;
  final String? siteWeb;
  final String? devise;
  final int? anneeCreation;

  const InformationsEtablissement({
    this.nomOfficiel,
    this.nomCourt,
    this.sigle,
    this.codeEcole,
    this.type,
    this.adresse,
    this.ville,
    this.region,
    this.pays,
    this.telephone,
    this.email,
    this.siteWeb,
    this.devise,
    this.anneeCreation,
  });

  factory InformationsEtablissement.fromJson(Map<String, dynamic> json) {
    return InformationsEtablissement(
      nomOfficiel: json['nom'] as String?,
      nomCourt: json['nom_court'] as String?,
      sigle: json['sigle'] as String?,
      codeEcole: json['code_ecole'] as String?,
      type: json['type_etablissement'] as String?,
      adresse: json['adresse'] as String?,
      ville: json['ville'] as String?,
      region: json['region'] as String?,
      pays: json['pays'] as String?,
      telephone: json['telephone'] as String?,
      email: json['email'] as String?,
      siteWeb: json['site_web'] as String?,
      devise: json['devise'] as String?,
      anneeCreation: json['annee_creation'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'nom': nomOfficiel,
        'nom_court': nomCourt,
        'sigle': sigle,
        'type_etablissement': type,
        'adresse': adresse,
        'ville': ville,
        'region': region,
        'pays': pays,
        'telephone': telephone,
        'email': email,
        'site_web': siteWeb,
        'devise': devise,
        'annee_creation': anneeCreation,
      };

  InformationsEtablissement copyWith({
    String? nomOfficiel,
    String? nomCourt,
    String? sigle,
    String? type,
    String? adresse,
    String? ville,
    String? region,
    String? pays,
    String? telephone,
    String? email,
    String? siteWeb,
    String? devise,
    int? anneeCreation,
  }) {
    return InformationsEtablissement(
      nomOfficiel: nomOfficiel ?? this.nomOfficiel,
      nomCourt: nomCourt ?? this.nomCourt,
      sigle: sigle ?? this.sigle,
      codeEcole: codeEcole,
      type: type ?? this.type,
      adresse: adresse ?? this.adresse,
      ville: ville ?? this.ville,
      region: region ?? this.region,
      pays: pays ?? this.pays,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      siteWeb: siteWeb ?? this.siteWeb,
      devise: devise ?? this.devise,
      anneeCreation: anneeCreation ?? this.anneeCreation,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Identité visuelle — GET /parametres/identite-visuelle
// ══════════════════════════════════════════════════════════
class IdentiteVisuelle {
  final String? logoPrincipal;
  final String? logoSecondaire;
  final String? cachetNumerique;
  final String? signatureDirecteur;
  final String couleurPrincipale;
  final String couleurSecondaire;
  final String? couleurBoutons;
  final String? couleurEntetes;

  const IdentiteVisuelle({
    this.logoPrincipal,
    this.logoSecondaire,
    this.cachetNumerique,
    this.signatureDirecteur,
    required this.couleurPrincipale,
    required this.couleurSecondaire,
    this.couleurBoutons,
    this.couleurEntetes,
  });

  factory IdentiteVisuelle.fromJson(Map<String, dynamic> json) {
    final logos = json['logos'] as Map<String, dynamic>? ?? {};
    final principal = logos['principal'] as Map<String, dynamic>?;
    final secondaire = logos['secondaire'] as Map<String, dynamic>?;
    final cachet = json['cachet'] as Map<String, dynamic>?;
    final signature = json['signature'] as Map<String, dynamic>?;
    final couleurs = json['couleurs'] as Map<String, dynamic>? ?? {};

    return IdentiteVisuelle(
      logoPrincipal: principal?['url'] as String?,
      logoSecondaire: secondaire?['url'] as String?,
      cachetNumerique: cachet?['url'] as String?,
      signatureDirecteur: signature?['url'] as String?,
      couleurPrincipale: couleurs['couleur_principale'] as String? ?? '#1E3A8A',
      couleurSecondaire: couleurs['couleur_secondaire'] as String? ?? '#0D9488',
      couleurBoutons: couleurs['couleur_boutons'] as String?,
      couleurEntetes: couleurs['couleur_entetes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'couleur_principale': couleurPrincipale,
        'couleur_secondaire': couleurSecondaire,
        'couleur_boutons': couleurBoutons,
        'couleur_entetes': couleurEntetes,
      };

  IdentiteVisuelle copyWith({
    String? logoPrincipal,
    String? logoSecondaire,
    String? cachetNumerique,
    String? signatureDirecteur,
    String? couleurPrincipale,
    String? couleurSecondaire,
    String? couleurBoutons,
    String? couleurEntetes,
  }) {
    return IdentiteVisuelle(
      logoPrincipal: logoPrincipal ?? this.logoPrincipal,
      logoSecondaire: logoSecondaire ?? this.logoSecondaire,
      cachetNumerique: cachetNumerique ?? this.cachetNumerique,
      signatureDirecteur: signatureDirecteur ?? this.signatureDirecteur,
      couleurPrincipale: couleurPrincipale ?? this.couleurPrincipale,
      couleurSecondaire: couleurSecondaire ?? this.couleurSecondaire,
      couleurBoutons: couleurBoutons ?? this.couleurBoutons,
      couleurEntetes: couleurEntetes ?? this.couleurEntetes,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Direction — GET/PUT /parametres/direction
// ══════════════════════════════════════════════════════════
class InfosDirecteur {
  final String? nom;
  final String? prenom;
  final String? fonction;
  final String? telephone;
  final String? email;

  const InfosDirecteur({
    this.nom,
    this.prenom,
    this.fonction,
    this.telephone,
    this.email,
  });

  factory InfosDirecteur.fromJson(Map<String, dynamic> json) {
    return InfosDirecteur(
      nom: json['directeur_nom'] as String?,
      prenom: json['directeur_prenom'] as String?,
      fonction: json['directeur_fonction'] as String?,
      telephone: json['directeur_telephone'] as String?,
      email: json['directeur_email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'directeur_nom': nom,
        'directeur_prenom': prenom,
        'directeur_fonction': fonction,
        'directeur_telephone': telephone,
        'directeur_email': email,
      };
}

// ══════════════════════════════════════════════════════════
// Organisation académique — GET/PUT /parametres/academique
// ══════════════════════════════════════════════════════════
class ParametreAcademique {
  // trimestres | semestres — reflète annees_academiques.type_periodes de
  // l'année active (pas une colonne séparée, voir ParametreAcademiqueController).
  final String? typeDecoupage;
  final int baremeNoteMax;
  final bool coefficientsParMatiere;
  final bool coefficientsParClasse;
  final bool coefficientsParNiveau;
  final String modeCalculMoyenne;

  const ParametreAcademique({
    this.typeDecoupage,
    this.baremeNoteMax = 20,
    this.coefficientsParMatiere = true,
    this.coefficientsParClasse = false,
    this.coefficientsParNiveau = false,
    this.modeCalculMoyenne = 'simple',
  });

  factory ParametreAcademique.fromJson(Map<String, dynamic> json) {
    final p = json['parametre'] as Map<String, dynamic>? ?? json;
    return ParametreAcademique(
      typeDecoupage: json['type_decoupage_annee_active'] as String?,
      baremeNoteMax: p['bareme_note_max'] as int? ?? 20,
      coefficientsParMatiere: p['coefficients_par_matiere'] as bool? ?? true,
      coefficientsParClasse: p['coefficients_par_classe'] as bool? ?? false,
      coefficientsParNiveau: p['coefficients_par_niveau'] as bool? ?? false,
      modeCalculMoyenne: p['mode_calcul_moyenne_matiere'] as String? ?? 'simple',
    );
  }

  Map<String, dynamic> toJson({bool inclureTypeDecoupage = false}) => {
        if (inclureTypeDecoupage && typeDecoupage != null) 'type_decoupage': typeDecoupage,
        'bareme_note_max': baremeNoteMax,
        'coefficients_par_matiere': coefficientsParMatiere,
        'coefficients_par_classe': coefficientsParClasse,
        'coefficients_par_niveau': coefficientsParNiveau,
        'mode_calcul_moyenne_matiere': modeCalculMoyenne,
      };

  ParametreAcademique copyWith({
    String? typeDecoupage,
    int? baremeNoteMax,
    bool? coefficientsParMatiere,
    bool? coefficientsParClasse,
    bool? coefficientsParNiveau,
    String? modeCalculMoyenne,
  }) {
    return ParametreAcademique(
      typeDecoupage: typeDecoupage ?? this.typeDecoupage,
      baremeNoteMax: baremeNoteMax ?? this.baremeNoteMax,
      coefficientsParMatiere: coefficientsParMatiere ?? this.coefficientsParMatiere,
      coefficientsParClasse: coefficientsParClasse ?? this.coefficientsParClasse,
      coefficientsParNiveau: coefficientsParNiveau ?? this.coefficientsParNiveau,
      modeCalculMoyenne: modeCalculMoyenne ?? this.modeCalculMoyenne,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Bulletins — GET/PUT /parametres/bulletins
// ══════════════════════════════════════════════════════════
class ParametreBulletin {
  final bool afficherLogo;
  final bool afficherMatricule;
  final bool afficherEffectif;
  final bool afficherCoefficients;
  final bool afficherRang;
  final bool afficherAppreciations;
  final bool afficherAbsences;
  final bool afficherRetards;
  final bool afficherDecisionConseil;
  final bool afficherSignatureDirecteur;
  final bool afficherCachet;
  final String modeleBulletin;

  const ParametreBulletin({
    this.afficherLogo = true,
    this.afficherMatricule = true,
    this.afficherEffectif = true,
    this.afficherCoefficients = true,
    this.afficherRang = true,
    this.afficherAppreciations = true,
    this.afficherAbsences = true,
    this.afficherRetards = true,
    this.afficherDecisionConseil = false,
    this.afficherSignatureDirecteur = true,
    this.afficherCachet = true,
    this.modeleBulletin = 'standard',
  });

  factory ParametreBulletin.fromJson(Map<String, dynamic> json) {
    final p = json['parametre'] as Map<String, dynamic>? ?? json;
    return ParametreBulletin(
      afficherLogo: p['afficher_logo'] as bool? ?? true,
      afficherMatricule: p['afficher_matricule'] as bool? ?? true,
      afficherEffectif: p['afficher_effectif'] as bool? ?? true,
      afficherCoefficients: p['afficher_coefficients'] as bool? ?? true,
      afficherRang: p['afficher_rang'] as bool? ?? true,
      afficherAppreciations: p['afficher_appreciations'] as bool? ?? true,
      afficherAbsences: p['afficher_absences'] as bool? ?? true,
      afficherRetards: p['afficher_retards'] as bool? ?? true,
      afficherDecisionConseil: p['afficher_decision_conseil'] as bool? ?? false,
      afficherSignatureDirecteur: p['afficher_signature_directeur'] as bool? ?? true,
      afficherCachet: p['afficher_cachet'] as bool? ?? true,
      modeleBulletin: p['modele_bulletin'] as String? ?? 'standard',
    );
  }

  Map<String, dynamic> toJson() => {
        'afficher_logo': afficherLogo,
        'afficher_matricule': afficherMatricule,
        'afficher_effectif': afficherEffectif,
        'afficher_coefficients': afficherCoefficients,
        'afficher_rang': afficherRang,
        'afficher_appreciations': afficherAppreciations,
        'afficher_absences': afficherAbsences,
        'afficher_retards': afficherRetards,
        'afficher_decision_conseil': afficherDecisionConseil,
        'afficher_signature_directeur': afficherSignatureDirecteur,
        'afficher_cachet': afficherCachet,
        'modele_bulletin': modeleBulletin,
      };

  ParametreBulletin copyWith({
    bool? afficherLogo,
    bool? afficherMatricule,
    bool? afficherEffectif,
    bool? afficherCoefficients,
    bool? afficherRang,
    bool? afficherAppreciations,
    bool? afficherAbsences,
    bool? afficherRetards,
    bool? afficherDecisionConseil,
    bool? afficherSignatureDirecteur,
    bool? afficherCachet,
    String? modeleBulletin,
  }) {
    return ParametreBulletin(
      afficherLogo: afficherLogo ?? this.afficherLogo,
      afficherMatricule: afficherMatricule ?? this.afficherMatricule,
      afficherEffectif: afficherEffectif ?? this.afficherEffectif,
      afficherCoefficients: afficherCoefficients ?? this.afficherCoefficients,
      afficherRang: afficherRang ?? this.afficherRang,
      afficherAppreciations: afficherAppreciations ?? this.afficherAppreciations,
      afficherAbsences: afficherAbsences ?? this.afficherAbsences,
      afficherRetards: afficherRetards ?? this.afficherRetards,
      afficherDecisionConseil: afficherDecisionConseil ?? this.afficherDecisionConseil,
      afficherSignatureDirecteur: afficherSignatureDirecteur ?? this.afficherSignatureDirecteur,
      afficherCachet: afficherCachet ?? this.afficherCachet,
      modeleBulletin: modeleBulletin ?? this.modeleBulletin,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Validation des notes — GET/PUT /parametres/validation-notes
// ══════════════════════════════════════════════════════════
class ParametreValidationNote {
  final bool validationObligatoire;
  final List<String> rolesAutorisesValidation;
  final bool modificationApresValidation;
  final bool verrouillageAutoCloture;

  const ParametreValidationNote({
    this.validationObligatoire = true,
    this.rolesAutorisesValidation = const ['directeur', 'censeur'],
    this.modificationApresValidation = false,
    this.verrouillageAutoCloture = true,
  });

  factory ParametreValidationNote.fromJson(Map<String, dynamic> json) {
    final p = json['parametre'] as Map<String, dynamic>? ?? json;
    final roles = p['roles_autorises_validation'] as List?;
    return ParametreValidationNote(
      validationObligatoire: p['validation_obligatoire'] as bool? ?? true,
      rolesAutorisesValidation:
          roles != null && roles.isNotEmpty ? roles.map((r) => r as String).toList() : const ['directeur', 'censeur'],
      modificationApresValidation: p['modification_apres_validation'] as bool? ?? false,
      verrouillageAutoCloture: p['verrouillage_auto_cloture_periode'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'validation_obligatoire': validationObligatoire,
        'roles_autorises_validation': rolesAutorisesValidation,
        'modification_apres_validation': modificationApresValidation,
        'verrouillage_auto_cloture_periode': verrouillageAutoCloture,
      };

  ParametreValidationNote copyWith({
    bool? validationObligatoire,
    List<String>? rolesAutorisesValidation,
    bool? modificationApresValidation,
    bool? verrouillageAutoCloture,
  }) {
    return ParametreValidationNote(
      validationObligatoire: validationObligatoire ?? this.validationObligatoire,
      rolesAutorisesValidation: rolesAutorisesValidation ?? this.rolesAutorisesValidation,
      modificationApresValidation: modificationApresValidation ?? this.modificationApresValidation,
      verrouillageAutoCloture: verrouillageAutoCloture ?? this.verrouillageAutoCloture,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Frais scolaires — GET/PUT /parametres/frais
// ══════════════════════════════════════════════════════════
class ParametreFrais {
  final String devise;
  final int nombreTranchesDefaut;
  final bool penalitesActives;
  final double? montantPenaliteRetard;
  final bool paiementPartielAutorise;
  final int seuilJoursRetard;

  const ParametreFrais({
    this.devise = 'FCFA',
    this.nombreTranchesDefaut = 3,
    this.penalitesActives = false,
    this.montantPenaliteRetard,
    this.paiementPartielAutorise = true,
    this.seuilJoursRetard = 0,
  });

  factory ParametreFrais.fromJson(Map<String, dynamic> json) {
    final p = json['parametre'] as Map<String, dynamic>? ?? json;
    return ParametreFrais(
      devise: p['devise'] as String? ?? 'FCFA',
      nombreTranchesDefaut: p['nombre_tranches_defaut'] as int? ?? 3,
      penalitesActives: p['penalites_actives'] as bool? ?? false,
      montantPenaliteRetard: p['montant_penalite_retard'] != null
          ? double.tryParse(p['montant_penalite_retard'].toString())
          : null,
      paiementPartielAutorise: p['paiement_partiel_autorise'] as bool? ?? true,
      seuilJoursRetard: p['seuil_jours_retard_non_en_regle'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'devise': devise,
        'nombre_tranches_defaut': nombreTranchesDefaut,
        'penalites_actives': penalitesActives,
        'montant_penalite_retard': montantPenaliteRetard,
        'paiement_partiel_autorise': paiementPartielAutorise,
        'seuil_jours_retard_non_en_regle': seuilJoursRetard,
      };

  ParametreFrais copyWith({
    String? devise,
    int? nombreTranchesDefaut,
    bool? penalitesActives,
    double? montantPenaliteRetard,
    bool? paiementPartielAutorise,
    int? seuilJoursRetard,
  }) {
    return ParametreFrais(
      devise: devise ?? this.devise,
      nombreTranchesDefaut: nombreTranchesDefaut ?? this.nombreTranchesDefaut,
      penalitesActives: penalitesActives ?? this.penalitesActives,
      montantPenaliteRetard: montantPenaliteRetard ?? this.montantPenaliteRetard,
      paiementPartielAutorise: paiementPartielAutorise ?? this.paiementPartielAutorise,
      seuilJoursRetard: seuilJoursRetard ?? this.seuilJoursRetard,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Types de notifications de l'école — GET/PUT /parametres/notifications-ecole
// ══════════════════════════════════════════════════════════
class TypeNotificationEcole {
  final String cible; // parents | enseignants
  final String typeEvenement; // clé technique (ex: bulletin, paiement_retard)
  final String libelle;
  final bool actif;

  const TypeNotificationEcole({
    required this.cible,
    required this.typeEvenement,
    required this.libelle,
    required this.actif,
  });

  factory TypeNotificationEcole.fromJson(Map<String, dynamic> json, {String? cible}) {
    return TypeNotificationEcole(
      cible: cible ?? json['cible'] as String? ?? '',
      typeEvenement: json['cle'] as String? ?? json['type_evenement'] as String? ?? '',
      libelle: json['libelle'] as String? ?? '',
      actif: json['actif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'cible': cible,
        'type_evenement': typeEvenement,
        'actif': actif,
      };

  TypeNotificationEcole copyWith({bool? actif}) {
    return TypeNotificationEcole(
      cible: cible,
      typeEvenement: typeEvenement,
      libelle: libelle,
      actif: actif ?? this.actif,
    );
  }
}
