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
        table.recap td.label { color: #666; width: 220px; }
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

    <div class="titre-section">RAPPORT DE PAIEMENTS — {{ ucfirst($type_rapport) }}</div>
    <div class="sous-titre">
        @if(isset($rapport['periode_libelle']))
            {{ $rapport['periode_libelle'] }} (du {{ $rapport['date_debut'] }} au {{ $rapport['date_fin'] }})
        @else
            {{ $rapport['date'] }}
        @endif
        — Généré le {{ $genere_le }}
    </div>

    <table class="recap">
        <tr><td class="label">Nombre de paiements</td><td class="valeur">{{ $rapport['nombre_paiements'] }}</td></tr>
        @if(isset($rapport['total_encaisse']))
        <tr><td class="label">Total encaissé</td><td class="valeur">{{ number_format($rapport['total_encaisse'], 0, ',', ' ') }} FCFA</td></tr>
        @else
        <tr><td class="label">Montant attendu (année)</td><td class="valeur">{{ number_format($rapport['montant_attendu'], 0, ',', ' ') }} FCFA</td></tr>
        <tr><td class="label">Encaissé (année)</td><td class="valeur">{{ number_format($rapport['montant_encaisse_annee'], 0, ',', ' ') }} FCFA</td></tr>
        <tr><td class="label">Reste à recouvrer (année)</td><td class="valeur">{{ number_format($rapport['reste_a_recouvrer'], 0, ',', ' ') }} FCFA</td></tr>
        <tr><td class="label">Encaissé sur la période</td><td class="valeur">{{ number_format($rapport['total_encaisse_periode'], 0, ',', ' ') }} FCFA</td></tr>
        @endif
    </table>

    <div class="titre-section">VENTILATION PAR MODE DE PAIEMENT</div>
    <table class="donnees">
        <thead><tr><th>Mode</th><th>Nombre</th><th>Montant</th></tr></thead>
        <tbody>
            @foreach($rapport['par_mode_paiement'] as $m)
            <tr><td>{{ $m['libelle'] }}</td><td>{{ $m['nombre'] }}</td><td>{{ number_format($m['montant'], 0, ',', ' ') }} FCFA</td></tr>
            @endforeach
        </tbody>
    </table>

    @if(isset($rapport['par_classe']))
    <div class="titre-section">VENTILATION PAR CLASSE</div>
    <table class="donnees">
        <thead><tr><th>Classe</th><th>Nombre</th><th>Montant</th></tr></thead>
        <tbody>
            @foreach($rapport['par_classe'] as $c)
            <tr><td>{{ $c['classe_nom'] }}</td><td>{{ $c['nombre'] }}</td><td>{{ number_format($c['montant'], 0, ',', ' ') }} FCFA</td></tr>
            @endforeach
        </tbody>
    </table>
    @endif

    @if(isset($rapport['par_jour']))
    <div class="titre-section">DÉTAIL PAR JOUR</div>
    <table class="donnees">
        <thead><tr><th>Jour</th><th>Nombre</th><th>Montant</th></tr></thead>
        <tbody>
            @foreach($rapport['par_jour'] as $j)
            <tr><td>{{ $j['libelle'] }}</td><td>{{ $j['nombre_paiements'] }}</td><td>{{ number_format($j['total_encaisse'], 0, ',', ' ') }} FCFA</td></tr>
            @endforeach
        </tbody>
    </table>
    @endif

    @if(isset($rapport['evolution_mensuelle']))
    <div class="titre-section">ÉVOLUTION MENSUELLE</div>
    <table class="donnees">
        <thead><tr><th>Mois</th><th>Montant encaissé</th></tr></thead>
        <tbody>
            @foreach($rapport['evolution_mensuelle'] as $m)
            <tr><td>{{ $m['libelle'] }}</td><td>{{ number_format($m['montant'], 0, ',', ' ') }} FCFA</td></tr>
            @endforeach
        </tbody>
    </table>
    @endif

    @if(isset($rapport['transactions']))
    <div class="titre-section">DÉTAIL DES TRANSACTIONS</div>
    <table class="donnees">
        <thead><tr><th>N° Reçu</th><th>Élève</th><th>Frais</th><th>Mode</th><th>Montant</th></tr></thead>
        <tbody>
            @foreach($rapport['transactions'] as $t)
            <tr><td>{{ $t['numero_recu'] }}</td><td>{{ $t['eleve'] }}</td><td>{{ $t['frais_nom'] }}</td><td>{{ $t['mode_paiement'] }}</td><td>{{ number_format($t['montant'], 0, ',', ' ') }} FCFA</td></tr>
            @endforeach
        </tbody>
    </table>
    @endif

    <div class="footer">Généré le {{ $genere_le }} via Smart School Manager (SSM)</div>
</body>
</html>
