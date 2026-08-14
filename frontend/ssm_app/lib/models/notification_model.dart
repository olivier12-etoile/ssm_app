import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════
// CategorieNotification
// ══════════════════════════════════════════════════════════
enum CategorieNotification {
  scolarite('scolarite', 'Scolarité', Icons.school_outlined),
  finances('finances', 'Finances', Icons.payments_outlined),
  presence('presence', 'Présence', Icons.event_busy_outlined),
  administration('administration', 'Administration', Icons.admin_panel_settings_outlined),
  discipline('discipline', 'Discipline', Icons.gavel_outlined),
  vieScolaire('vie_scolaire', 'Vie scolaire', Icons.groups_outlined);

  final String valeurApi;
  final String libelle;
  final IconData icone;

  const CategorieNotification(this.valeurApi, this.libelle, this.icone);

  static CategorieNotification depuisApi(String valeur) => CategorieNotification.values.firstWhere(
        (c) => c.valeurApi == valeur,
        orElse: () => CategorieNotification.vieScolaire,
      );
}

// ══════════════════════════════════════════════════════════
// TypeCible
// ══════════════════════════════════════════════════════════
enum TypeCible {
  ecoleEntiere('ecole_entiere', 'École entière', Icons.apartment_outlined),
  classe('classe', 'Classe', Icons.class_outlined),
  plusieursClasses('plusieurs_classes', 'Plusieurs classes', Icons.grid_view_outlined),
  eleve('eleve', 'Élève', Icons.person_outline),
  enseignants('enseignants', 'Enseignants', Icons.co_present_outlined),
  personnelAdministratif('personnel_administratif', 'Personnel administratif', Icons.badge_outlined);

  final String valeurApi;
  final String libelle;
  final IconData icone;

  const TypeCible(this.valeurApi, this.libelle, this.icone);

  static TypeCible depuisApi(String valeur) => TypeCible.values.firstWhere(
        (t) => t.valeurApi == valeur,
        orElse: () => TypeCible.eleve,
      );
}

// ══════════════════════════════════════════════════════════
// CanalNotification
// ══════════════════════════════════════════════════════════
enum CanalNotification {
  whatsapp('whatsapp', 'WhatsApp', Icons.chat_outlined, Color(0xFF16A34A)),
  sms('sms', 'SMS', Icons.sms_outlined, Color(0xFF0284C7)),
  interne('interne', 'Interne', Icons.notifications_active_outlined, Color(0xFF1E3A8A)),
  email('email', 'Email', Icons.email_outlined, Color(0xFFD97706));

  final String valeurApi;
  final String libelle;
  final IconData icone;
  final Color couleur;

  const CanalNotification(this.valeurApi, this.libelle, this.icone, this.couleur);

  static CanalNotification depuisApi(String valeur) => CanalNotification.values.firstWhere(
        (c) => c.valeurApi == valeur,
        orElse: () => CanalNotification.whatsapp,
      );
}

// ══════════════════════════════════════════════════════════
// StatutNotification (statut global de l'envoi)
// ══════════════════════════════════════════════════════════
enum StatutNotification {
  preparation('preparation', 'En préparation', Color(0xFF94A3B8)),
  programmee('programmee', 'Programmée', Color(0xFF0284C7)),
  enCours('en_cours', 'En cours', Color(0xFFD97706)),
  envoyee('envoyee', 'Envoyée', Color(0xFF16A34A)),
  echecPartiel('echec_partiel', 'Échec partiel', Color(0xFFEA580C)),
  echec('echec', 'Échec', Color(0xFFDC2626));

  final String valeurApi;
  final String libelle;
  final Color couleur;

  const StatutNotification(this.valeurApi, this.libelle, this.couleur);

  static StatutNotification depuisApi(String valeur) => StatutNotification.values.firstWhere(
        (s) => s.valeurApi == valeur,
        orElse: () => StatutNotification.preparation,
      );
}

// ══════════════════════════════════════════════════════════
// StatutDestinataire (statut individuel d'un destinataire)
// ══════════════════════════════════════════════════════════
enum StatutDestinataire {
  enAttente('en_attente', 'En attente', Color(0xFF94A3B8)),
  envoye('envoye', 'Envoyé', Color(0xFF0284C7)),
  delivre('delivre', 'Délivré', Color(0xFF16A34A)),
  echec('echec', 'Échec', Color(0xFFDC2626));

  final String valeurApi;
  final String libelle;
  final Color couleur;

  const StatutDestinataire(this.valeurApi, this.libelle, this.couleur);

  static StatutDestinataire depuisApi(String valeur) => StatutDestinataire.values.firstWhere(
        (s) => s.valeurApi == valeur,
        orElse: () => StatutDestinataire.enAttente,
      );
}

// ══════════════════════════════════════════════════════════
// ModeleMessage
// ══════════════════════════════════════════════════════════
class ModeleMessage {
  final int? id;
  final String nom;
  final CategorieNotification categorie;
  final String contenu;
  final List<String> variablesDisponibles;
  final List<String> variablesUtilisees;
  final bool actif;
  final bool modifiable;

  ModeleMessage({
    this.id,
    required this.nom,
    required this.categorie,
    required this.contenu,
    this.variablesDisponibles = const [],
    this.variablesUtilisees = const [],
    this.actif = true,
    this.modifiable = true,
  });

  factory ModeleMessage.fromJson(Map<String, dynamic> json) {
    return ModeleMessage(
      id: json['id'] as int?,
      nom: json['nom'] as String,
      categorie: CategorieNotification.depuisApi(json['categorie'] as String),
      contenu: json['contenu'] as String,
      variablesDisponibles: ((json['variables_disponibles'] as List?) ?? [])
          .map((v) => v.toString())
          .toList(),
      variablesUtilisees: ((json['variables_utilisees'] as List?) ?? [])
          .map((v) => v.toString())
          .toList(),
      actif: json['actif'] as bool? ?? true,
      modifiable: json['modifiable'] as bool? ?? true,
    );
  }

  // Corps de requête pour la création/modification (POST/PUT /notifications/modeles).
  Map<String, dynamic> toJsonCreation() {
    return {
      'nom': nom,
      'categorie': categorie.valeurApi,
      'contenu': contenu,
      'variables_disponibles': variablesDisponibles,
      'actif': actif,
    };
  }
}

// ══════════════════════════════════════════════════════════
// NotificationDestinataire
// ══════════════════════════════════════════════════════════
class NotificationDestinataire {
  final int? id;
  final int? eleveId;
  final int? userId;
  final String nomDestinataire;
  final String? telephone;
  final StatutDestinataire statut;

  NotificationDestinataire({
    this.id,
    this.eleveId,
    this.userId,
    required this.nomDestinataire,
    this.telephone,
    required this.statut,
  });

  factory NotificationDestinataire.fromJson(Map<String, dynamic> json) {
    return NotificationDestinataire(
      id: json['id'] as int?,
      eleveId: json['eleve_id'] as int?,
      userId: json['user_id'] as int?,
      nomDestinataire: json['nom_destinataire'] as String? ?? '—',
      telephone: json['telephone'] as String?,
      statut: StatutDestinataire.depuisApi(json['statut'] as String? ?? 'en_attente'),
    );
  }
}

// ══════════════════════════════════════════════════════════
// NotificationSSM
// ══════════════════════════════════════════════════════════
class NotificationSSM {
  final int? id;
  final String titre;
  final String message;
  final int? modeleMessageId;
  // Catégorie du modèle utilisé, si connue (issue de la relation
  // modele_message quand elle est chargée par l'API) — sert au filtrage et
  // aux permissions côté écran, pas envoyée telle quelle à la création.
  final CategorieNotification? categorie;
  final TypeCible typeCible;
  final Map<String, dynamic> cibles;
  final CanalNotification canal;
  final bool urgent;
  final bool programmee;
  final DateTime? dateEnvoiPrevue;
  final StatutNotification statut;
  final int nombreDestinataires;
  final int nombreEnvoyes;
  final int nombreEchoues;
  final String? auteurNom;
  final DateTime? createdAt;
  final List<NotificationDestinataire> destinataires;

  NotificationSSM({
    this.id,
    required this.titre,
    required this.message,
    this.modeleMessageId,
    this.categorie,
    required this.typeCible,
    this.cibles = const {},
    required this.canal,
    this.urgent = false,
    this.programmee = false,
    this.dateEnvoiPrevue,
    this.statut = StatutNotification.preparation,
    this.nombreDestinataires = 0,
    this.nombreEnvoyes = 0,
    this.nombreEchoues = 0,
    this.auteurNom,
    this.createdAt,
    this.destinataires = const [],
  });

  bool get estEnAttente =>
      statut == StatutNotification.preparation ||
      statut == StatutNotification.programmee ||
      statut == StatutNotification.enCours;

  bool get estEnEchec =>
      statut == StatutNotification.echec || statut == StatutNotification.echecPartiel;

  double get progressionEnvoi =>
      nombreDestinataires > 0 ? (nombreEnvoyes / nombreDestinataires).clamp(0.0, 1.0) : 0.0;

  factory NotificationSSM.fromJson(Map<String, dynamic> json) {
    final modele = json['modele_message'] as Map<String, dynamic>?;
    final auteur = json['auteur'] as Map<String, dynamic>?;
    final destinatairesJson = json['destinataires'] as List?;

    return NotificationSSM(
      id: json['id'] as int?,
      titre: json['titre'] as String? ?? '',
      message: json['message'] as String? ?? '',
      modeleMessageId: json['modele_message_id'] as int?,
      categorie: modele != null && modele['categorie'] != null
          ? CategorieNotification.depuisApi(modele['categorie'] as String)
          : null,
      typeCible: TypeCible.depuisApi(json['type_cible'] as String),
      cibles: (json['cibles'] as Map?)?.cast<String, dynamic>() ?? {},
      canal: CanalNotification.depuisApi(json['canal'] as String),
      urgent: json['urgent'] as bool? ?? false,
      programmee: json['programmee'] as bool? ?? false,
      dateEnvoiPrevue: json['date_envoi_prevue'] != null
          ? DateTime.tryParse(json['date_envoi_prevue'].toString())
          : null,
      statut: StatutNotification.depuisApi(json['statut'] as String? ?? 'preparation'),
      nombreDestinataires: json['nombre_destinataires'] as int? ?? 0,
      nombreEnvoyes: json['nombre_envoyes'] as int? ?? 0,
      nombreEchoues: json['nombre_echoues'] as int? ?? 0,
      auteurNom: auteur?['name'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      destinataires: (destinatairesJson ?? [])
          .map((d) => NotificationDestinataire.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  // Corps de requête pour la création (POST /notifications).
  Map<String, dynamic> toJsonCreation() {
    return {
      'titre': titre,
      'message': message,
      'modele_message_id': modeleMessageId,
      'type_cible': typeCible.valeurApi,
      'cibles': cibles,
      'canal': canal.valeurApi,
      'urgent': urgent,
      'programmee': programmee,
      if (dateEnvoiPrevue != null) 'date_envoi_prevue': dateEnvoiPrevue!.toIso8601String(),
    };
  }
}

// ══════════════════════════════════════════════════════════
// ParametreDeclencheur — activation/désactivation d'un déclencheur auto
// ══════════════════════════════════════════════════════════
class ParametreDeclencheur {
  final String cle;
  final String libelle;
  final bool actif;

  ParametreDeclencheur({required this.cle, required this.libelle, required this.actif});

  factory ParametreDeclencheur.fromJson(Map<String, dynamic> json) {
    return ParametreDeclencheur(
      cle: json['cle'] as String,
      libelle: json['libelle'] as String,
      actif: json['actif'] as bool? ?? true,
    );
  }
}
