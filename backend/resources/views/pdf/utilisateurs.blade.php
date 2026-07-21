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
            padding: 12px 16px;
            border-radius: 6px;
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
        .titre-section {
            margin-top: 18px;
            font-size: 14px;
            font-weight: bold;
            color: {{ $ecole['couleur_primaire'] }};
            border-bottom: 2px solid {{ $ecole['couleur_primaire'] }};
            padding-bottom: 4px;
        }
        .sous-titre {
            margin-top: 4px;
            font-size: 10px;
            color: #666;
        }
        table.donnees {
            width: 100%;
            border-collapse: collapse;
            margin-top: 8px;
        }
        table.donnees th {
            background-color: {{ $ecole['couleur_primaire'] }};
            color: #fff;
            padding: 6px;
            font-size: 11px;
            text-align: left;
        }
        table.donnees td {
            padding: 6px;
            border-bottom: 1px solid #e0e0e0;
            font-size: 11px;
            vertical-align: middle;
        }
        table.donnees tr:nth-child(even) {
            background-color: #f7f7f7;
        }
        .photo {
            width: 26px;
            height: 26px;
            border-radius: 50%;
        }
        .photo-vide {
            width: 26px;
            height: 26px;
            border-radius: 50%;
            background-color: {{ $ecole['couleur_primaire'] }};
            color: #fff;
            text-align: center;
            font-size: 11px;
            font-weight: bold;
            line-height: 26px;
        }
        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 8px;
            font-size: 10px;
            color: #fff;
        }
        .stats-box {
            margin-top: 16px;
            padding: 12px 16px;
            background-color: #f0f0f0;
            border-left: 6px solid {{ $ecole['couleur_primaire'] }};
            border-radius: 4px;
        }
        .stats-box table {
            width: 100%;
        }
        .stats-box .valeur {
            font-size: 16px;
            font-weight: bold;
            color: {{ $ecole['couleur_primaire'] }};
        }
        .footer {
            margin-top: 20px;
            font-size: 9px;
            color: #999;
            text-align: center;
        }
    </style>
</head>
<body>

    <div class="entete">
        <h1>{{ $ecole['nom'] }}</h1>
        <p>Code école : {{ $ecole['code_ecole'] }}</p>
    </div>

    <div class="titre-section">LISTE DES UTILISATEURS</div>
    <div class="sous-titre">
        Généré le {{ $genere_le }}
        @if(!empty($filtres['role'])) &nbsp;|&nbsp; Rôle : {{ ucfirst($filtres['role']) }} @endif
        @if(!is_null($filtres['actif'])) &nbsp;|&nbsp; Statut : {{ $filtres['actif'] ? 'Actifs' : 'Désactivés' }} @endif
        @if(empty($filtres['role']) && is_null($filtres['actif'])) &nbsp;|&nbsp; Aucun filtre appliqué @endif
    </div>

    <table class="donnees">
        <thead>
            <tr>
                <th style="width: 8%;">Photo</th>
                <th style="width: 26%;">Nom complet</th>
                <th style="width: 14%;">Rôle</th>
                <th style="width: 24%;">Email</th>
                <th style="width: 16%;">Téléphone</th>
                <th style="width: 12%;">Statut</th>
            </tr>
        </thead>
        <tbody>
            @foreach($utilisateurs as $u)
            <tr>
                <td>
                    @if($u->photo_path)
                        <img class="photo" src="{{ public_path('storage/' . $u->photo_path) }}">
                    @else
                        <div class="photo-vide">{{ strtoupper(substr($u->name, 0, 1)) }}</div>
                    @endif
                </td>
                <td>{{ trim($u->name . ' ' . $u->prenom) }}</td>
                <td>{{ ucfirst($u->role) }}</td>
                <td>{{ $u->email }}</td>
                <td>{{ $u->telephone ?? '—' }}</td>
                <td>
                    <span class="badge" style="background-color: {{ $u->actif ? '#16A34A' : '#DC2626' }};">
                        {{ $u->actif ? 'Actif' : 'Désactivé' }}
                    </span>
                </td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="stats-box">
        <table>
            <tr>
                <td>
                    <strong>Directeur</strong><br>
                    <span class="valeur">{{ $par_role['directeur'] }}</span>
                </td>
                <td>
                    <strong>Censeurs</strong><br>
                    <span class="valeur">{{ $par_role['censeur'] }}</span>
                </td>
                <td>
                    <strong>Secrétaires</strong><br>
                    <span class="valeur">{{ $par_role['secretaire'] }}</span>
                </td>
                <td>
                    <strong>Enseignants</strong><br>
                    <span class="valeur">{{ $par_role['enseignant'] }}</span>
                </td>
                <td>
                    <strong>Total</strong><br>
                    <span class="valeur">{{ count($utilisateurs) }}</span>
                </td>
            </tr>
        </table>
    </div>

    <div class="footer">
        {{ count($utilisateurs) }} utilisateur(s) — Généré le {{ $genere_le }} via Smart School Manager (SSM)
    </div>

</body>
</html>
