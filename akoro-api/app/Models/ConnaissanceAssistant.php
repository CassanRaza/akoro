<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class ConnaissanceAssistant extends Model
{
    protected $table = 'connaissances_assistant';

    // Catégories de la base de connaissances FAB'IA (ordre d'affichage)
    public const CATEGORIES = [
        'presentation' => 'Présentation du FabLab',
        'localisation' => 'Localisation et accès',
        'espaces' => 'Espaces du FabLab',
        'equipements' => 'Équipements',
        'parcours' => 'Parcours de formation',
        'horaires' => 'Horaires et organisation',
        'reglement' => 'Règlement et présence',
        'application' => 'Utilisation de l’application AKORO',
        'contacts' => 'Contacts et services',
    ];

    protected $fillable = [
        'etablissement_id',
        'categorie',
        'titre',
        'contenu',
        'questions_types',
        'mots_cles',
        'a_valider',
        'actif',
        'ordre',
    ];

    protected function casts(): array
    {
        return [
            'a_valider' => 'boolean',
            'actif' => 'boolean',
        ];
    }

    public function etablissement()
    {
        return $this->belongsTo(Etablissement::class);
    }

    /** Connaissances visibles pour un établissement : les siennes + les communes. */
    public function scopePourEtablissement(Builder $query, ?int $etablissementId): Builder
    {
        return $query->where(function ($q) use ($etablissementId) {
            $q->whereNull('etablissement_id');
            if ($etablissementId) {
                $q->orWhere('etablissement_id', $etablissementId);
            }
        });
    }
}
