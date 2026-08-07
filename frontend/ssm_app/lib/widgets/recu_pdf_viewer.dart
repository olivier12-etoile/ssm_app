import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../services/paiement_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _rouge = Color(0xFFDC2626);

// Widget simple pour télécharger puis afficher le reçu PDF d'un paiement.
// Le projet n'embarque aucun lecteur PDF intégré (aucun package de ce
// type n'est présent dans pubspec.yaml) : comme pour les bulletins, on
// télécharge le fichier localement puis on l'ouvre avec l'application
// PDF par défaut de l'appareil (package open_file).
class RecuPdfViewer extends StatefulWidget {
  final int paiementId;
  final String? numeroRecu;
  final bool compact;

  const RecuPdfViewer({
    super.key,
    required this.paiementId,
    this.numeroRecu,
    this.compact = false,
  });

  // Télécharge et ouvre le reçu sans passer par le widget (réutilisable
  // depuis un bouton personnalisé, ex: écran de confirmation de paiement).
  static Future<void> telechargerEtOuvrir(
    BuildContext context,
    int paiementId, {
    String? numeroRecu,
  }) async {
    try {
      final octets = await PaiementService.telechargerRecu(paiementId);
      final dossier = await getTemporaryDirectory();
      final nomFichier = 'recu_${numeroRecu ?? paiementId}.pdf';
      final fichier = File('${dossier.path}/$nomFichier');
      await fichier.writeAsBytes(octets);
      await OpenFile.open(fichier.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur ouverture du reçu : ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: _rouge,
          ),
        );
      }
    }
  }

  @override
  State<RecuPdfViewer> createState() => _RecuPdfViewerState();
}

class _RecuPdfViewerState extends State<RecuPdfViewer> {
  bool _enCours = false;

  Future<void> _telecharger() async {
    setState(() => _enCours = true);
    await RecuPdfViewer.telechargerEtOuvrir(
      context,
      widget.paiementId,
      numeroRecu: widget.numeroRecu,
    );
    if (mounted) setState(() => _enCours = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _enCours
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _indigo),
            )
          : IconButton(
              icon: const Icon(Icons.receipt_long, color: _indigo),
              tooltip: 'Télécharger le reçu',
              onPressed: _telecharger,
            );
    }

    return OutlinedButton.icon(
      onPressed: _enCours ? null : _telecharger,
      style: OutlinedButton.styleFrom(foregroundColor: _indigo),
      icon: _enCours
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _indigo),
            )
          : const Icon(Icons.picture_as_pdf, size: 18),
      label: Text(
        widget.numeroRecu != null ? 'Voir le reçu ${widget.numeroRecu}' : 'Voir le reçu',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    );
  }
}
