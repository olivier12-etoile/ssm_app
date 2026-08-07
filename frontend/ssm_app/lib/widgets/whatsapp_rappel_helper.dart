import 'package:url_launcher/url_launcher.dart';
import '../models/dashboard_frais_model.dart';
import '../services/whatsapp_service.dart';

String _formatMontant(double m) {
  final entier = m.round();
  final texte = entier.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texte[i]);
  }
  return '$buffer FCFA';
}

// Construit le message de rappel pour un élève débiteur.
String genererMessageRappelWhatsApp(EleveDebiteur debiteur) {
  return 'Bonjour, nous vous rappelons que ${_formatMontant(debiteur.montantRestant)} '
      'reste dû pour ${debiteur.nomComplet} (${debiteur.classe}). '
      'Merci de régulariser rapidement.';
}

// Construit l'URL wa.me pré-remplie pour un élève débiteur.
// Retourne null si aucun numéro de téléphone parent n'est enregistré.
String? genererLienRappelWhatsApp(EleveDebiteur debiteur) {
  final telephone = debiteur.telephoneParent;
  if (telephone == null || telephone.isEmpty) return null;

  final numero = WhatsAppService.nettoyerNumero(telephone);
  final messageEncode = Uri.encodeComponent(genererMessageRappelWhatsApp(debiteur));
  return 'https://wa.me/$numero?text=$messageEncode';
}

// Ouvre WhatsApp avec le rappel pré-rempli pour cet élève débiteur.
// Retourne false si aucun numéro n'est enregistré ou si l'ouverture échoue.
Future<bool> ouvrirRappelWhatsApp(EleveDebiteur debiteur) async {
  final lien = genererLienRappelWhatsApp(debiteur);
  if (lien == null) return false;

  final uri = Uri.parse(lien);
  if (await canLaunchUrl(uri)) {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}
