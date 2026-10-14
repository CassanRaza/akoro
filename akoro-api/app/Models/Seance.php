<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Seance extends Model
{
    use HasFactory;

    protected $fillable = [
        'parcours_id', 'lecon_id', 'date', 'heure_debut', 'heure_fin',
        'attendus', 'absences_generees_le',
    ];

    protected function casts(): array
    {
        return [
            'date' => 'date:Y-m-d',
            'absences_generees_le' => 'datetime',
        ];
    }

    public function parcours()
    {
        return $this->belongsTo(Parcours::class);
    }

    public function lecon()
    {
        return $this->belongsTo(Lecon::class);
    }

    public function absences()
    {
        return $this->hasMany(Absence::class);
    }
}