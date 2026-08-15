@php
    $couleurPrimaire = $ecole['couleur_primaire'] ?? '#1565C0';
    $couleurEntetes = $ecole['couleur_entetes'] ?? $couleurPrimaire;

    $libellesDecision = [
        'encouragements' => 'Encouragements',
        'felicitations' => 'Félicitations',
        'tableau_honneur' => "Tableau d'honneur",
        'avertissement_travail' => 'Avertissement travail',
        'avertissement_conduite' => 'Avertissement conduite',
        'passage' => 'Admis(e) en classe supérieure',
        'redoublement' => 'Redouble la classe',
        'exclusion' => 'Exclusion',
    ];
@endphp
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 24px; }
        body { font-family: 'DejaVu Sans', sans-serif; font-size: 11px; color: #222; }

        .entete { display: table; width: 100%; background-color: {{ $couleurEntetes }}; color: #fff; border-radius: 6px; padding: 10px 14px; }
        .entete-logo { display: table-cell; width: 55px; vertical-align: middle; }
        .entete-logo img { max-width: 48px; max-height: 48px; }
        .entete-texte { display: table-cell; vertical-align: middle; padding-left: 10px; }
        .entete-texte h1 { margin: 0; font-size: 16px; }
        .entete-texte p { margin: 2px 0 0; font-size: 9px; color: #f0f0f0; }

        .titre-bulletin { text-align: center; margin-top: 14px; font-size: 15px; font-weight: bold; letter-spacing: 1px; color: {{ $couleurPrimaire }}; text-transform: uppercase; }
        .sous-titre { text-align: center; font-size: 11px; color: #666; margin-top: 2px; }

        table.infos { width: 100%; margin-top: 12px; border-collapse: collapse; }
        table.infos td { padding: 3px 6px; font-size: 11px; }
        table.infos td.label { color: #666; width: 110px; }

        table.notes { width: 100%; border-collapse: collapse; margin-top: 14px; }
        table.notes th { background-color: {{ $couleurPrimaire }}; color: #fff; padding: 6px; font-size: 10px; text-align: left; }
        table.notes td { padding: 5px 6px; border-bottom: 1px solid #e0e0e0; font-size: 10px; }
        table.notes tr:nth-child(even) { background-color: #f7f7f7; }

        .recap { margin-top: 14px; padding: 10px 14px; background-color: #f0f0f0; border-left: 6px solid {{ $couleurPrimaire }}; border-radius: 4px; }
        .recap table { width: 100%; }
        .recap td { padding: 2px 6px; font-size: 11px; vertical-align: top; }
        .moyenne { font-size: 20px; font-weight: bold; color: {{ $couleurPrimaire }}; }

        .decision { margin-top: 12px; padding: 8px 14px; background-color: {{ $couleurPrimaire }}; border-radius: 6px; text-align: center; }
        .decision span { color: #fff; font-size: 13px; font-weight: bold; letter-spacing: 1px; }

        table.presence { width: 100%; margin-top: 12px; border-collapse: collapse; }
        table.presence td { padding: 6px 8px; font-size: 11px; border: 1px solid #e0e0e0; text-align: center; }

        table.signatures { width: 100%; margin-top: 40px; }
        table.signatures td { width: 33%; text-align: center; font-size: 10px; vertical-align: bottom; }
        table.signatures .zone-signature { height: 46px; }
        table.signatures img.signature-img { max-height: 42px; }
        table.signatures img.cachet-img { max-height: 58px; }
        table.signatures .trait { border-top: 1px solid #999; padding-top: 4px; }

        .footer { margin-top: 16px; font-size: 8px; color: #999; text-align: center; }
    </style>
</head>
<body>

    <div class="entete">
        @if($parametre->afficher_logo && !empty($ecole['logo']))
        <div class="entete-logo"><img src="{{ $ecole['logo'] }}" alt="logo"></div>
        @endif
        <div class="entete-texte">
            <h1>{{ $ecole['nom'] }}@if(!empty($ecole['sigle'])) ({{ $ecole['sigle'] }})@endif</h1>
            <p>
                @if(!empty($ecole['adresse'])){{ $ecole['adresse'] }}@endif
                @if(!empty($ecole['ville'])) &nbsp;–&nbsp;{{ $ecole['ville'] }}@endif
                @if(!empty($ecole['telephone'])) &nbsp;|&nbsp;Tél : {{ $ecole['telephone'] }}@endif
                @if(!empty($ecole['email'])) &nbsp;|&nbsp;{{ $ecole['email'] }}@endif
            </p>
            @if(!empty($ecole['devise']))
            <p><em>{{ $ecole['devise'] }}</em></p>
            @endif
        </div>
    </div>

    <div class="titre-bulletin">Bulletin de notes</div>
    <div class="sous-titre">{{ $periode->nom }} — Année scolaire {{ $annee->libelle ?? '' }}</div>

    <table class="infos">
        <tr>
            <td class="label">Élève</td>
            <td><strong>{{ $eleve->nom }} {{ $eleve->prenom }}</strong></td>
            @if($parametre->afficher_matricule)
            <td class="label">Matricule</td>
            <td>{{ $eleve->matricule }}</td>
            @endif
        </tr>
        <tr>
            <td class="label">Sexe</td>
            <td>{{ $eleve->sexe === 'M' ? 'Masculin' : 'Féminin' }}</td>
            <td class="label">Date de naissance</td>
            <td>{{ $eleve->date_naissance ? \Illuminate\Support\Carbon::parse($eleve->date_naissance)->format('d/m/Y') : '—' }}</td>
        </tr>
        <tr>
            <td class="label">Classe</td>
            <td>{{ $classe->nom }}</td>
            @if($parametre->afficher_effectif)
            <td class="label">Effectif classe</td>
            <td>{{ $bulletin->effectif_classe }}</td>
            @endif
        </tr>
    </table>

    <table class="notes">
        <thead>
            <tr>
                <th style="width: 34%;">Matière</th>
                @if($parametre->afficher_coefficients)
                <th style="width: 12%;">Coefficient</th>
                @endif
                <th style="width: 14%;">Note /20</th>
                <th style="width: 16%;">Moy. classe</th>
                @if($parametre->afficher_appreciations)
                <th>Appréciation</th>
                @endif
            </tr>
        </thead>
        <tbody>
            @foreach($bulletin->details as $detail)
            <tr>
                <td>{{ $detail->nom_matiere }}</td>
                @if($parametre->afficher_coefficients)
                <td>{{ number_format($detail->coefficient, 2, ',', '') }}</td>
                @endif
                <td><strong>{{ number_format($detail->note, 2, ',', '') }}</strong></td>
                <td>{{ $detail->moyenne_matiere_classe !== null ? number_format($detail->moyenne_matiere_classe, 2, ',', '') : '—' }}</td>
                @if($parametre->afficher_appreciations)
                <td>{{ $detail->appreciation_matiere ?? '—' }}</td>
                @endif
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="recap">
        <table>
            <tr>
                <td>
                    <strong>Total coefficients :</strong> {{ number_format($bulletin->total_coefficients, 2, ',', '') }}<br>
                    <strong>Total des points :</strong> {{ number_format($bulletin->total_points, 2, ',', '') }}
                </td>
                <td style="text-align: right;">
                    <span class="moyenne">{{ number_format($bulletin->moyenne_generale, 2, ',', '') }}/20</span>
                    @if($parametre->afficher_rang && $bulletin->rang)
                    <br><span>
                        Rang : {{ $bulletin->rang }}{{ $bulletin->rang === 1 ? 'er' : 'e' }}{{ $bulletin->rang_ex_aequo ? ' ex æquo' : '' }}
                        / {{ $bulletin->effectif_classe }}
                    </span>
                    @endif
                </td>
            </tr>
        </table>
    </div>

    @if($parametre->afficher_decision_conseil && $bulletin->decision_conseil)
    <div class="decision">
        <span>{{ strtoupper($libellesDecision[$bulletin->decision_conseil] ?? $bulletin->decision_conseil) }}</span>
    </div>
    @endif

    @if($parametre->afficher_absences || $parametre->afficher_retards)
    <table class="presence">
        <tr>
            @if($parametre->afficher_absences)
            <td><strong>{{ $bulletin->absences_justifiees }}</strong><br>Absences justifiées</td>
            <td><strong>{{ $bulletin->absences_non_justifiees }}</strong><br>Absences non justifiées</td>
            @endif
            @if($parametre->afficher_retards)
            <td><strong>{{ $bulletin->retards }}</strong><br>Retards</td>
            @endif
        </tr>
    </table>
    @endif

    @if(!empty($bulletin->appreciation_generale))
    <table class="infos" style="margin-top: 12px;">
        <tr><td class="label">Appréciation générale</td><td>{{ $bulletin->appreciation_generale }}</td></tr>
    </table>
    @endif

    <table class="signatures">
        <tr>
            <td>
                <div class="zone-signature"></div>
                <div class="trait">Le Professeur Principal<br>{{ $bulletin->professeurPrincipal->name ?? '' }}</div>
            </td>
            @if($parametre->afficher_cachet)
            <td>
                @if(!empty($ecole['cachet']))
                <img src="{{ $ecole['cachet'] }}" class="cachet-img" alt="cachet">
                @endif
                <div class="trait">Cachet de l'établissement</div>
            </td>
            @endif
            @if($parametre->afficher_signature_directeur)
            <td>
                @if(!empty($ecole['signature_directeur']))
                <img src="{{ $ecole['signature_directeur'] }}" class="signature-img" alt="signature">
                @endif
                <div class="trait">Le Directeur<br>{{ $ecole['directeur_nom'] ?? '' }}</div>
            </td>
            @endif
        </tr>
    </table>

    <div class="footer">
        Bulletin {{ $bulletin->statut }} — généré le {{ $genere_le }} via Smart School Manager (SSM)
    </div>

</body>
</html>
