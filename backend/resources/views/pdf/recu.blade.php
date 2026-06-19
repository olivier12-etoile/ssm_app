<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 25px; }
        body {
            font-family: 'DejaVu Sans', sans-serif;
            font-size: 12px;
            color: #222;
        }
        .entete {
            background-color: {{ $ecole['couleur_primaire'] }};
            color: #ffffff;
            padding: 14px 18px;
            border-radius: 6px;
            text-align: center;
        }
        .entete h1 {
            margin: 0;
            font-size: 18px;
        }
        .entete p {
            margin: 2px 0 0 0;
            font-size: 11px;
            color: #f0f0f0;
        }
        .titre-recu {
            text-align: center;
            margin-top: 20px;
            font-size: 16px;
            font-weight: bold;
            color: {{ $ecole['couleur_primaire'] }};
            letter-spacing: 2px;
        }
        .numero-recu {
            text-align: center;
            font-size: 11px;
            color: #999;
            margin-top: 4px;
        }
        table.infos {
            width: 100%;
            margin-top: 24px;
            border-collapse: collapse;
        }
        table.infos td {
            padding: 8px 10px;
            font-size: 12px;
            border-bottom: 1px solid #eee;
        }
        table.infos td.label {
            color: #666;
            width: 160px;
        }
        .montant-box {
            margin-top: 24px;
            padding: 20px;
            background-color: #f5f5f5;
            border: 2px dashed {{ $ecole['couleur_primaire'] }};
            border-radius: 8px;
            text-align: center;
        }
        .montant-box .label {
            font-size: 12px;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .montant-box .montant {
            font-size: 28px;
            font-weight: bold;
            color: {{ $ecole['couleur_primaire'] }};
            margin-top: 6px;
        }
        .signature {
            margin-top: 50px;
            width: 100%;
        }
        .signature td {
            width: 50%;
            text-align: center;
            font-size: 11px;
            padding-top: 30px;
            border-top: 1px solid #999;
        }
        .footer {
            margin-top: 30px;
            font-size: 9px;
            color: #999;
            text-align: center;
        }
        .cachet {
            margin-top: 10px;
            text-align: right;
            font-size: 10px;
            color: #999;
            font-style: italic;
        }
    </style>
</head>
<body>

    <div class="entete">
        <h1>{{ $ecole['nom'] }}</h1>
        <p>Code école : {{ $ecole['code_ecole'] }}
            @if(!empty($ecole['telephone'])) &nbsp;|&nbsp; Tél : {{ $ecole['telephone'] }} @endif
            @if(!empty($ecole['adresse'])) &nbsp;|&nbsp; {{ $ecole['adresse'] }} @endif
        </p>
    </div>

    <div class="titre-recu">REÇU DE PAIEMENT</div>
    <div class="numero-recu">N° {{ $numero_recu }}</div>

    <table class="infos">
        <tr>
            <td class="label">Élève</td>
            <td><strong>{{ $eleve['nom'] }} {{ $eleve['prenom'] }}</strong></td>
        </tr>
        <tr>
            <td class="label">Matricule</td>
            <td>{{ $eleve['matricule'] }}</td>
        </tr>
        <tr>
            <td class="label">Année académique</td>
            <td>{{ $annee }}</td>
        </tr>
        <tr>
            <td class="label">Tranche</td>
            <td>{{ $tranche }}</td>
        </tr>
        <tr>
            <td class="label">Date du paiement</td>
            <td>{{ $date_paiement }}</td>
        </tr>
        @if(!empty($reference))
        <tr>
            <td class="label">Référence</td>
            <td>{{ $reference }}</td>
        </tr>
        @endif
    </table>

    <div class="montant-box">
        <div class="label">Montant payé</div>
        <div class="montant">{{ number_format($montant, 0, ',', ' ') }} FCFA</div>
    </div>

    <div class="cachet">Cachet et signature de l'établissement</div>

    <table class="signature">
        <tr>
            <td>Le Caissier / Secrétaire</td>
            <td>Le Directeur</td>
        </tr>
    </table>

    <div class="footer">
        Reçu généré le {{ $genere_le }} via Smart School Manager (SSM)<br>
        Document à conserver comme preuve de paiement
    </div>

</body>
</html>