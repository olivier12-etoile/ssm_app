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
        .titre-section { margin-top: 18px; font-size: 14px; font-weight: bold; color: #DC2626; border-bottom: 2px solid #DC2626; padding-bottom: 4px; }
        .sous-titre { margin-top: 4px; font-size: 10px; color: #666; }
        .nom-classe { margin-top: 14px; font-size: 12px; font-weight: bold; color: {{ $ecole['couleur_primaire'] }}; }
        table.donnees { width: 100%; border-collapse: collapse; margin-top: 6px; }
        table.donnees th { background-color: #f1f5f9; color: #334155; padding: 6px; font-size: 11px; text-align: left; }
        table.donnees td { padding: 6px; border-bottom: 1px solid #e0e0e0; font-size: 11px; vertical-align: middle; }
        .footer { margin-top: 20px; font-size: 9px; color: #999; text-align: center; }
    </style>
</head>
<body>
    <div class="entete">
        <h1>{{ $ecole['nom'] }}</h1>
        <p>Code école : {{ $ecole['code_ecole'] }}</p>
    </div>

    <div class="titre-section">ÉLÈVES DÉBITEURS</div>
    <div class="sous-titre">{{ $total }} élève(s) — Généré le {{ $genere_le }}</div>

    @foreach($classes as $classeNom => $eleves)
    <div class="nom-classe">{{ $classeNom }}</div>
    <table class="donnees">
        <thead>
            <tr>
                <th style="width: 12%;">Matricule</th>
                <th style="width: 28%;">Nom complet</th>
                <th style="width: 20%;">Montant restant</th>
                <th style="width: 15%;">Jours de retard</th>
                <th style="width: 25%;">Téléphone parent</th>
            </tr>
        </thead>
        <tbody>
            @foreach($eleves as $e)
            <tr>
                <td>{{ $e['matricule'] }}</td>
                <td>{{ $e['nom'] }} {{ $e['prenom'] }}</td>
                <td>{{ number_format($e['montant_restant'], 0, ',', ' ') }} FCFA</td>
                <td>{{ $e['jours_de_retard'] }}</td>
                <td>{{ $e['telephone_parent'] ?? '—' }}</td>
            </tr>
            @endforeach
        </tbody>
    </table>
    @endforeach

    <div class="footer">Généré le {{ $genere_le }} via Smart School Manager (SSM)</div>
</body>
</html>
