<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class Paiement extends Model
{
    use FiltreParEcole;

    protected $table = 'paiements';

    protected $fillable = [
        'ecole_id',
        'eleve_id',
        'frais_scolaire_id',
        'echeance_id',
        'montant',
        'mode_paiement',
        'session_caisse_id',
        'reference',
        'date_paiement',
        'observation',
        'numero_recu',
        'statut',
        'annule_par',
        'motif_annulation',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'montant'       => 'decimal:2',
            'date_paiement' => 'date',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Paiement $paiement) {
            if (empty($paiement->numero_recu)) {
                $paiement->numero_recu = static::genererNumeroRecu();
            }
        });
    }

    // Génère un numéro de reçu unique au format REC-{annee}-{sequence}.
    public static function genererNumeroRecu(): string
    {
        $annee = now()->year;
        $prefixe = "REC-{$annee}-";

        $dernier = static::withoutGlobalScope('parEcole')
            ->where('numero_recu', 'like', $prefixe . '%')
            ->orderByDesc('id')
            ->first();

        $sequence = 1;
        if ($dernier) {
            $sequence = ((int) substr($dernier->numero_recu, strlen($prefixe))) + 1;
        }

        return $prefixe . str_pad((string) $sequence, 5, '0', STR_PAD_LEFT);
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }

    public function fraisScolaire()
    {
        return $this->belongsTo(FraisScolaire::class, 'frais_scolaire_id');
    }

    public function echeance()
    {
        return $this->belongsTo(EcheanceFrais::class, 'echeance_id');
    }

    public function annulePar()
    {
        return $this->belongsTo(User::class, 'annule_par');
    }

    public function creePar()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function journalOperations()
    {
        return $this->hasMany(JournalOperationFrais::class, 'paiement_id');
    }

    public function sessionCaisse()
    {
        return $this->belongsTo(SessionCaisse::class, 'session_caisse_id');
    }

    public function corrections()
    {
        return $this->hasMany(CorrectionPaiement::class, 'paiement_id');
    }
}
