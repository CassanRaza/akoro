<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Soumission extends Model
{
    use HasFactory;

    public const STATUTS = ['en_attente', 'rendu', 'corrige'];

    protected $fillable = [
        'devoir_id',
        'user_id',
        'fichier',
        'nom_fichier',
        'note',
        'commentaire',
        'statut',
        'date_soumission',
    ];

    protected function casts(): array
    {
        return [
            'date_soumission' => 'datetime',
            'note'            => 'decimal:2',
        ];
    }

    public function devoir()
    {
        return $this->belongsTo(Devoir::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}