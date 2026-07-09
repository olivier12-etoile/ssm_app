import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  // Nettoie un numéro de téléphone pour WhatsApp
  // Accepte: "90123456" ou "+22890123456" ou "228 90 12 34 56"
  static String _nettoyerNumero(String numero) {
    String n = numero.replaceAll(RegExp(r'[^\d+]'), '');
    // Si pas d'indicatif pays, on ajoute le Togo (228) par défaut
    if (!n.startsWith('+')) {
      if (n.startsWith('228')) {
        n = '+$n';
      } else {
        n = '+228$n';
      }
    }
    return n.replaceAll('+', '');
  }

  // Ouvre WhatsApp avec un message pré-rempli
  static Future<bool> envoyerMessage({
    required String numeroTelephone,
    required String message,
  }) async {
    final numero = _nettoyerNumero(numeroTelephone);
    final messageEncode = Uri.encodeComponent(message);
    final url = 'https://wa.me/$numero?text=$messageEncode';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  // ── Templates de messages ─────────────────────────────

  static String messageAbsence({
    required String nomParent,
    required String nomEleve,
    required String classe,
    required String heure,
    required String nomEcole,
  }) {
    return 'Bonjour $nomParent,\n\n'
        'Votre enfant $nomEleve ($classe) a été marqué absent ce matin à $heure.\n\n'
        'Merci de justifier cette absence auprès de l\'administration.\n\n'
        '$nomEcole';
  }

  static String messageRecuPaiement({
    required String nomParent,
    required String nomEleve,
    required String classe,
    required String montant,
    required String tranche,
    required String nomEcole,
  }) {
    return 'Bonjour $nomParent,\n\n'
        'Nous accusons réception de votre paiement de $montant FCFA '
        '($tranche) pour $nomEleve ($classe).\n\n'
        'Merci de votre confiance.\n\n'
        '$nomEcole';
  }

  static String messageRappelPaiement({
    required String nomParent,
    required String nomEleve,
    required String classe,
    required String montantDu,
    required String dateLimit,
    required String nomEcole,
  }) {
    return 'Bonjour $nomParent,\n\n'
        'Nous vous rappelons que le solde de scolarité de $nomEleve ($classe) '
        'est de $montantDu FCFA.\n\n'
        'Merci d\'effectuer le règlement avant le $dateLimit.\n\n'
        '$nomEcole';
  }

  static String messageBulletin({
    required String nomParent,
    required String nomEleve,
    required String classe,
    required String periode,
    required String moyenne,
    required String mention,
    required String nomEcole,
  }) {
    return 'Bonjour $nomParent,\n\n'
        'Le bulletin de $periode de votre enfant $nomEleve ($classe) est disponible.\n\n'
        'Moyenne : $moyenne/20\n'
        'Mention : $mention\n\n'
        '$nomEcole';
  }
}