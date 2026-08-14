import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'notifications_attente_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFF8FAFC);

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
      SnackBar(content: Text(msg), backgroundColor: _rouge),
    );
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _vert),
    );
  }

  Future<void> _annulerProgrammee() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annuler l\'envoi ?', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Text(
          "Cette notification programmée sera annulée et ne sera jamais envoyée.",
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
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
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Détail de la notification', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _erreur != null
              ? _vueErreur(_erreur!)
              : notif == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _charger,
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
                                  backgroundColor: _rouge,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                                  backgroundColor: _vert,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.send),
                                label: const Text('Reprendre l\'envoi WhatsApp (chaîne)'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SSMSectionTitre(titre: 'Destinataires (${notif.destinataires.length})'),
                          if (notif.destinataires.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Aucun destinataire enregistré.',
                                  style: GoogleFonts.inter(color: _gris),
                                ),
                              ),
                            )
                          else
                            ...notif.destinataires.map(_carteDestinataire),
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
            const Icon(Icons.error_outline, color: _rouge, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _carteEntete(NotificationSSM notif) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (notif.urgent) ...[
                const Icon(Icons.priority_high, color: _rouge, size: 18),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  notif.titre,
                  style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: _texteFonce),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SSMBadge(label: notif.statut.libelle, couleur: notif.statut.couleur, icone: Icons.circle),
              SSMBadge(label: notif.canal.libelle, couleur: notif.canal.couleur, icone: notif.canal.icone),
              SSMBadge(label: notif.typeCible.libelle, couleur: _indigo, icone: notif.typeCible.icone),
              if (notif.categorie != null)
                SSMBadge(label: notif.categorie!.libelle, couleur: _teal, icone: notif.categorie!.icone),
            ],
          ),
          const Divider(height: 28),
          Text(
            notif.message,
            style: GoogleFonts.inter(fontSize: 14, color: _texte, height: 1.5),
          ),
          const SizedBox(height: 14),
          Text(
            notif.programmee
                ? 'Programmée pour le ${_formatDateHeure(notif.dateEnvoiPrevue)}'
                : 'Créée le ${_formatDateHeure(notif.createdAt)}'
                    '${notif.auteurNom != null ? ' par ${notif.auteurNom}' : ''}',
            style: GoogleFonts.inter(fontSize: 12, color: _gris),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progression de l\'envoi', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce)),
              Text(
                '${notif.nombreEnvoyes} / ${notif.nombreDestinataires}',
                style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: _indigo),
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
              color: notif.estEnEchec ? _rouge : _vert,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _statChiffre('Envoyés', envoyes, const Color(0xFF0284C7)),
              _statChiffre('Délivrés', delivres, _vert),
              _statChiffre('Échoués', echoues, _rouge),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChiffre(String label, int valeur, Color couleur) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$valeur',
            style: GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.w700, color: couleur),
          ),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: _texte)),
        ],
      ),
    );
  }

  Widget _carteDestinataire(NotificationDestinataire d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: d.statut.couleur.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              d.eleveId != null ? Icons.family_restroom : Icons.person,
              color: d.statut.couleur,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.nomDestinataire,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
                ),
                if (d.telephone != null)
                  Text(
                    d.telephone!,
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _gris),
                  ),
              ],
            ),
          ),
          SSMBadge(label: d.statut.libelle, couleur: d.statut.couleur),
        ],
      ),
    );
  }
}
