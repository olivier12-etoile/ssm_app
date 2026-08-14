<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Ecole extends Model
{
    protected $table = 'ecoles';

    protected $fillable = [
        'nom',
        'code_ecole',
        'chemin_logo',
        'couleur_primaire',
        'couleur_secondaire',
        'telephone',
        'adresse',
        'statut_abonnement',
        'expire_le',
        'nom_court',
        'sigle',
        'type_etablissement',
        'ville',
        'region',
        'pays',
        'email',
        'site_web',
        'devise',
        'annee_creation',
        'logo_secondaire',
        'cachet_numerique',
        'signature_directeur',
        'couleur_boutons',
        'couleur_entetes',
        'directeur_nom',
        'directeur_prenom',
        'directeur_fonction',
        'directeur_telephone',
        'directeur_email',
    ];

    protected $appends = [
        'logo_principal_url',
        'logo_secondaire_url',
        'cachet_numerique_url',
        'signature_directeur_url',
    ];

    public function getLogoPrincipalUrlAttribute()
    {
        return $this->chemin_logo ? asset('storage/' . $this->chemin_logo) : null;
    }

    public function getLogoSecondaireUrlAttribute()
    {
        return $this->logo_secondaire ? asset('storage/' . $this->logo_secondaire) : null;
    }

    public function getCachetNumeriqueUrlAttribute()
    {
        return $this->cachet_numerique ? asset('storage/' . $this->cachet_numerique) : null;
    }

    public function getSignatureDirecteurUrlAttribute()
    {
        return $this->signature_directeur ? asset('storage/' . $this->signature_directeur) : null;
    }

    public function utilisateurs()
    {
        return $this->hasMany(User::class, 'ecole_id');
    }

    public function classes()
    {
        return $this->hasMany(Classe::class, 'ecole_id');
    }

    public function annees()
    {
        return $this->hasMany(AnneeAcademique::class, 'ecole_id');
    }

    public function eleves()
    {
        return $this->hasMany(Eleve::class, 'ecole_id');
    }

    public function parametresAcademiques()
    {
        return $this->hasOne(ParametreAcademique::class, 'ecole_id');
    }

    public function parametresBulletins()
    {
        return $this->hasOne(ParametreBulletin::class, 'ecole_id');
    }

    public function parametresValidationNotes()
    {
        return $this->hasOne(ParametreValidationNote::class, 'ecole_id');
    }

    public function parametresClasses()
    {
        return $this->hasOne(ParametreClasse::class, 'ecole_id');
    }

    public function parametresMatieres()
    {
        return $this->hasOne(ParametreMatiere::class, 'ecole_id');
    }

    public function parametresFrais()
    {
        return $this->hasOne(ParametreFrais::class, 'ecole_id');
    }

    public function parametresSecurite()
    {
        return $this->hasOne(ParametreSecurite::class, 'ecole_id');
    }

    public function permissionsRoles()
    {
        return $this->hasMany(PermissionRole::class, 'ecole_id');
    }

    public function connexionsUtilisateurs()
    {
        return $this->hasMany(ConnexionUtilisateur::class, 'ecole_id');
    }

    public function journalGlobal()
    {
        return $this->hasMany(JournalGlobal::class, 'ecole_id');
    }

    public function sauvegardesInfo()
    {
        return $this->hasMany(SauvegardeInfo::class, 'ecole_id');
    }
}
