import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import 'notifications_attente_screen.dart';

// Couleurs de catégorie alignées sur la palette générale du thème (indigo /
// teal / ambre / rouge uniquement — voir SSMPalette) : 6 catégories pour 4
// teintes de base, réparties par famille (pédagogie/administratif en indigo,
// finances/vie scolaire en teal, présence en ambre, discipline en rouge).
const Map<CategorieNotification, Color> _couleursCategorie = {
  CategorieNotification.scolarite: SSMPalette.indigo,
  CategorieNotification.finances: SSMPalette.teal,
  CategorieNotification.presence: SSMPalette.ambre,
  CategorieNotification.administration: SSMPalette.indigo,
  CategorieNotification.discipline: SSMPalette.rouge,
  CategorieNotification.vieScolaire: SSMPalette.teal,
};

String _formatDateHeure(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════════════════
// Détail d'une notification : message complet, statistiques
// d'envoi, liste des destinataires avec leur statut individuel.
// ══════════════════════════════════════════════════════════
class DetailNotificationScreen extends StatefulWidget {
  final int notificationId;

  const DetailNotificationScreen({super.key, required this.notificationId});

  @override
  State<DetailNotificationScreen> createState() => _DetailNotificationScreenState();
}

class _DetailNotificationScreenState extends State<DetailNotificationScreen> {
  NotificationSSM? _notification;
  bool _chargement = true;
  bool _actionEnCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final notif = await NotificationService.getDetailNotification(widget.notificationId);
      if (!mounted) return;
      setState(() {
        _notification = notif;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge),
    );
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: SSMPalette.teal),
    );
  }

  Future<void> _annulerProgrammee() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annuler l\'envoi ?', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: Text(
          "Cette notification programmée sera annulée et ne sera jamais envoyée.",
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler l\'envoi'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _actionEnCours = true);
    try {
      await NotificationService.annulerProgrammee(widget.notificationId);
      if (!mounted) return;
      _afficherSucces('Notification programmée annulée.');
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _actionEnCours = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _reprendreEnvoiChaine() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsAttenteScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notif = _notification;

    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Détail de la notification', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _vueErreur(_erreur!)
                      : notif == null
                          ? const SizedBox.shrink()
                          : RefreshIndicator(
                              onRefresh: _charger,
                              color: SSMPalette.indigo,
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  _carteEntete(notif),
                                  const SizedBox(height: 16),
                                  _carteStatistiques(notif),
                                  if (notif.statut == StatutNotification.programmee) ...[
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _actionEnCours ? null : _annulerProgrammee,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: SSMPalette.rouge,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                                        ),
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text("Annuler l'envoi"),
                                      ),
                                    ),
                                  ],
                                  if (notif.canal == CanalNotification.whatsapp &&
                                      notif.destinataires.any((d) => d.statut == StatutDestinataire.envoye)) ...[
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _reprendreEnvoiChaine,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: SSMPalette.teal,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                                        ),
                                        icon: const Icon(Icons.send),
                                        label: const Text('Reprendre l\'envoi WhatsApp (chaîne)'),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  Text(
                                    'DESTINATAIRES (${notif.destinataires.length})',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.indigo, letterSpacing: 0.4),
                                  ),
                                  const SizedBox(height: 10),
                                  _tableDestinataires(notif),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueErreur(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _carteEntete(NotificationSSM notif) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (notif.urgent) ...[
                const Icon(Icons.priority_high, color: SSMPalette.rouge, size: 18),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  notif.titre,
                  style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SSMPill.couleur(label: notif.statut.libelle, couleur: notif.statut.couleur),
              SSMPill.couleur(label: notif.canal.libelle, couleur: notif.canal.couleur),
              SSMPill.couleur(label: notif.typeCible.libelle, couleur: SSMPalette.indigo),
              if (notif.categorie != null)
                SSMPill.couleur(label: notif.categorie!.libelle, couleur: _couleursCategorie[notif.categorie!] ?? SSMPalette.teal),
            ],
          ),
          const Divider(height: 28, color: SSMPalette.bordure),
          Text(
            notif.message,
            style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1, height: 1.5),
          ),
          const SizedBox(height: 14),
          Text(
            notif.programmee
                ? 'Programmée pour le ${_formatDateHeure(notif.dateEnvoiPrevue)}'
                : 'Créée le ${_formatDateHeure(notif.createdAt)}'
                    '${notif.auteurNom != null ? ' par ${notif.auteurNom}' : ''}',
            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3),
          ),
        ],
      ),
    );
  }

  Widget _carteStatistiques(NotificationSSM notif) {
    final envoyes = notif.destinataires.where((d) => d.statut == StatutDestinataire.envoye).length;
    final delivres = notif.destinataires.where((d) => d.statut == StatutDestinataire.delivre).length;
    final echoues = notif.destinataires.where((d) => d.statut == StatutDestinataire.echec).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progression de l\'envoi', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
              Text(
                '${notif.nombreEnvoyes} / ${notif.nombreDestinataires}',
                style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: notif.progressionEnvoi,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              color: notif.estEnEchec ? SSMPalette.rouge : SSMPalette.teal,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SSMStatCard(icone: Icons.send_outlined, couleur: const Color(0xFF0284C7), valeur: '$envoyes', label: 'Envoyés'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SSMStatCard(icone: Icons.check_circle_outline, couleur: SSMPalette.teal, valeur: '$delivres', label: 'Délivrés'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SSMStatCard(icone: Icons.error_outline, couleur: SSMPalette.rouge, valeur: '$echoues', label: 'Échoués'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableDestinataires(NotificationSSM notif) {
    if (notif.destinataires.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Aucun destinataire enregistré.', style: GoogleFonts.inter(color: SSMPalette.texte3)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SSMDataTable(
        colonnes: const [
          SSMDataColumn('Destinataire'),
          SSMDataColumn('Statut'),
        ],
        lignes: [
          for (final d in notif.destinataires)
            [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: d.statut.couleur.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(d.eleveId != null ? Icons.family_restroom : Icons.person, color: d.statut.couleur, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.nomDestinataire, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                      if (d.telephone != null)
                        Text(d.telephone!, style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: SSMPalette.texte3)),
                    ],
                  ),
                ],
              ),
              SSMPill.couleur(label: d.statut.libelle, couleur: d.statut.couleur),
            ],
        ],
      ),
    );
  }
}
