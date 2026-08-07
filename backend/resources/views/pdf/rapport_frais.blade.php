<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 25px; }
        body { font-family: 'DejaVu Sans', sans-serif; font-size: 12px; color: #222; }
        .entete { background-color: {{ $ecole['couleur_primaire'] }}; color: #fff; padding: 12px 16px; border-radius: 6px; }
        .entete h1 { margin: 0; font-size: 18px; }
        .entete p { margin: 2px 0 0 0; font-size: 11px; color: #f0f0f0; }
        .titre-section { margin-top: 18px; font-size: 14px; font-weight: bold; color: {{ $ecole['couleur_primaire'] }}; border-bottom: 2px solid {{ $ecole['couleur_primaire'] }}; padding-bottom: 4px; }
        .sous-titre { margin-top: 4px; font-size: 10px; color: #666; }
        table.recap { width: 100%; margin-top: 10px; border-collapse: collapse; }
        table.recap td { padding: 8px 10px; font-size: 12px; border-bottom: 1px solid #eee; }
        table.recap td.label { color: #666; width: 200px; }
        table.recap td.valeur { font-weight: bold; }
        table.donnees { width: 100%; border-collapse: collapse; margin-top: 8px; }
        table.donnees th { background-color: {{ $ecole['couleur_primaire'] }}; color: #fff; padding: 6px; font-size: 11px; text-align: left; }
        table.donnees td { padding: 6px; border-bottom: 1px solid #e0e0e0; font-size: 11px; vertical-align: middle; }
        table.donnees tr:nth-child(even) { background-color: #f7f7f7; }
        .footer { margin-top: 20px; font-size: 9px; color: #999; text-align: center; }
    </style>
</head>
<body>
    <div class="entete">
        <h1>{{ $ecole['nom'] }}</h1>
        <p>Code école : {{ $ecole['code_ecole'] }}</p>
    </div>

    <div class="titre-section">RAPPORT FINANCIER — {{ $periode_libelle }}</div>
    <div class="sous-titre">Du {{ $date_debut }} au {{ $date_fin }} — Généré le {{ $genere_le }}</div>

    <table class="recap">
        <tr><td class="label">Montant attendu (année en cours)</td><td class="valeur">{{ number_format($recapitulatif['montant_attendu'], 0, ',', ' ') }} FCFA</td></tr>
        <tr><td class="label">Montant encaissé (année en cours)</td><td class="valeur">{{ number_format($recapitulatif['montant_encaisse'], 0, ',', ' ') }} FCFA</td></tr>
        <tr><td class="label">Reste à recouvrer (année en cours)</td><td class="valeur">{{ number_format($recapitulatif['montant_restant'], 0, ',', ' ') }} FCFA</td></tr>
        <tr><td class="label">Encaissé sur la période</td><td class="valeur">{{ number_format($total_periode, 0, ',', ' ') }} FCFA</td></tr>
        <tr><td class="label">Nombre de paiements sur la période</td><td class="valeur">{{ count($paiements) }}</td></tr>
    </table>

    <div class="titre-section">DÉTAIL DES PAIEMENTS DE LA PÉRIODE</div>
    <table class="donnees">
        <thead>
            <tr>
                <th style="width: 12%;">N° Reçu</th>
                <th style="width: 12%;">Date</th>
                <th style="width: 25%;">Élève</th>
                <th style="width: 21%;">Frais</th>
                <th style="width: 15%;">Mode</th>
                <th style="width: 15%;">Montant</th>
            </tr>
        </thead>
        <tbody>
            @foreach($paiements as $p)
            <tr>
                <td>{{ $p->numero_recu }}</td>
                <td>{{ \Carbon\Carbon::parse($p->date_paiement)->format('d/m/Y') }}</td>
                <td>{{ $p->eleve->nom }} {{ $p->eleve->prenom }}</td>
                <td>{{ $p->fraisScolaire->nom }}</td>
                <td>{{ $p->mode_paiement }}</td>
                <td>{{ number_format($p->montant, 0, ',', ' ') }} FCFA</td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="footer">Généré le {{ $genere_le }} via Smart School Manager (SSM)</div>
</body>
</html>
