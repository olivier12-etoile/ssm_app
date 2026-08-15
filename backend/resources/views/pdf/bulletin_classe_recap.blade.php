<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 25px; }
        body { font-family: 'DejaVu Sans', sans-serif; font-size: 12px; color: #222; }
        .entete { background-color: {{ $ecole['couleur_primaire'] ?? '#1565C0' }}; color: #fff; padding: 12px 16px; border-radius: 6px; }
        .entete h1 { margin: 0; font-size: 18px; }
        .entete p { margin: 2px 0 0 0; font-size: 11px; color: #f0f0f0; }
        .titre-section { margin-top: 18px; font-size: 14px; font-weight: bold; color: {{ $ecole['couleur_primaire'] ?? '#1565C0' }}; border-bottom: 2px solid {{ $ecole['couleur_primaire'] ?? '#1565C0' }}; padding-bottom: 4px; }
        .sous-titre { margin-top: 4px; font-size: 10px; color: #666; }
        table.donnees { width: 100%; border-collapse: collapse; margin-top: 8px; }
        table.donnees th { background-color: {{ $ecole['couleur_primaire'] ?? '#1565C0' }}; color: #fff; padding: 6px; font-size: 11px; text-align: left; }
        table.donnees td { padding: 6px; border-bottom: 1px solid #e0e0e0; font-size: 11px; }
        table.donnees tr:nth-child(even) { background-color: #f7f7f7; }
        .footer { margin-top: 20px; font-size: 9px; color: #999; text-align: center; }
    </style>
</head>
<body>

    <div class="entete">
        <h1>{{ $ecole['nom'] ?? '' }}</h1>
        <p>Code école : {{ $ecole['code_ecole'] ?? '' }}</p>
    </div>

    <div class="titre-section">Bulletin récapitulatif — {{ $classe->nom }}</div>
    <div class="sous-titre">
        Période : {{ $periode->nom }}
        &nbsp;|&nbsp;Année scolaire : {{ $annee->libelle ?? '' }}
        &nbsp;|&nbsp;Effectif : {{ $effectif }}
        &nbsp;|&nbsp;Moyenne de classe : {{ $moyenne_classe }}/20
    </div>

    <table class="donnees">
        <thead>
            <tr>
                <th style="width: 10%;">Rang</th>
                <th style="width: 45%;">Nom complet</th>
                <th style="width: 20%;">Moyenne générale</th>
                <th>Décision du conseil</th>
            </tr>
        </thead>
        <tbody>
            @foreach($eleves as $e)
            <tr>
                <td>
                    {{ $e['rang'] ?? '—' }}{{ $e['rang'] === 1 ? 'er' : ($e['rang'] ? 'e' : '') }}
                    {{ $e['rang_ex_aequo'] ? ' ex æquo' : '' }}
                </td>
                <td>{{ $e['nom'] }} {{ $e['prenom'] }}</td>
                <td>{{ number_format($e['moyenne_generale'], 2, ',', '') }}/20</td>
                <td>{{ $e['decision_conseil'] ?? '—' }}</td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="footer">
        {{ count($eleves) }} élève(s) — Généré le {{ $genere_le }} via Smart School Manager (SSM)
    </div>

</body>
</html>
