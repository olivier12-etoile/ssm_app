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
        .carte { margin-top: 20px; border: 1px solid #e0e0e0; border-radius: 8px; padding: 16px; }
        .carte h2 { margin: 0 0 12px 0; font-size: 16px; color: {{ $ecole['couleur_primaire'] }}; }
        table.stats { width: 100%; border-collapse: collapse; }
        table.stats td { padding: 8px 10px; font-size: 12px; border-bottom: 1px solid #eee; }
        table.stats td.label { color: #666; width: 240px; }
        table.stats td.valeur { font-weight: bold; text-align: right; }
        .badge-regle { color: #16a34a; }
        .badge-partiel { color: #f97316; }
        .badge-non-regle { color: #dc2626; }
        .badge-retard { color: #b91c1c; }
        .footer { margin-top: 20px; font-size: 9px; color: #999; text-align: center; }
    </style>
</head>
<body>
    <div class="entete">
        <h1>{{ $ecole['nom'] }}</h1>
        <p>Code école : {{ $ecole['code_ecole'] }}</p>
    </div>

    <div class="carte">
        <h2>Situation financière — {{ $situation['classe_nom'] }}</h2>
        <table class="stats">
            <tr><td class="label">Effectif</td><td class="valeur">{{ $situation['nombre_eleves'] }}</td></tr>
            <tr><td class="label badge-regle">En règle</td><td class="valeur">{{ $situation['nombre_en_regle'] }}</td></tr>
            <tr><td class="label badge-partiel">Partiel</td><td class="valeur">{{ $situation['nombre_partiel'] }}</td></tr>
            <tr><td class="label badge-non-regle">Non réglé</td><td class="valeur">{{ $situation['nombre_non_regle'] }}</td></tr>
            <tr><td class="label badge-retard">En retard</td><td class="valeur">{{ $situation['nombre_en_retard'] }}</td></tr>
            <tr><td class="label">Montant attendu</td><td class="valeur">{{ number_format($situation['montant_attendu'], 0, ',', ' ') }} FCFA</td></tr>
            <tr><td class="label">Montant encaissé</td><td class="valeur">{{ number_format($situation['montant_encaisse'], 0, ',', ' ') }} FCFA</td></tr>
            <tr><td class="label">Reste à recouvrer</td><td class="valeur">{{ number_format($situation['reste_a_recouvrer'], 0, ',', ' ') }} FCFA</td></tr>
            <tr><td class="label">Taux de recouvrement</td><td class="valeur">{{ $situation['taux_recouvrement'] }} %</td></tr>
        </table>
    </div>

    <div class="footer">Généré le {{ $genere_le }} via Smart School Manager (SSM)</div>
</body>
</html>
