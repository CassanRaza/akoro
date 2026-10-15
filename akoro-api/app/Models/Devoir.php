<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Devoir extends Model
{
    use HasFactory;

    public const TYPES = ['qcm', 'rendu'];
    public const STATUTS = ['brouillon', 'programme', 'en_cours', 'termine', 'archive'];

    protected $fillable = [
        'etablissement_id',
        'parcours_id',
        'lecon_id',
        'created_by',
        'type',
        'titre',
        'description',
        'date_debut',
        'duree_minutes',
        'date_limite',
        'fichier_consigne',
        'statut',
    ];

    protected function casts(): array
    {
        return [
            'date_debut'  => 'datetime',
            'date_limite' => 'datetime',
        ];
    }

    public function etablissement()
    {
        return $this->belongsTo(Etablissement::class);
    }

    public function parcours()
    {
        return $this->belongsTo(Parcours::class);
    }

    public function lecon()
    {
        return $this->belongsTo(Lecon::class);
    }

    public function createur()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function questions()
    {
        return $this->hasMany(Question::class)->orderBy('ordre');
    }

    public function resultats()
    {
        return $this->hasMany(ResultatQuiz::class);
    }

    public function soumissions()
    {
        return $this->hasMany(Soumission::class);
    }
}