<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ResultatQuiz extends Model
{
    use HasFactory;

    protected $table = 'resultats_quiz';

    public const STATUTS = ['non_commence', 'en_cours', 'termine'];

    protected $fillable = [
        'devoir_id',
        'user_id',
        'score',
        'score_max',
        'pourcentage',
        'commence_le',
        'termine_le',
        'statut',
    ];

    protected function casts(): array
    {
        return [
            'commence_le' => 'datetime',
            'termine_le'  => 'datetime',
            'pourcentage' => 'decimal:2',
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

    public function reponses()
    {
        return $this->hasMany(Reponse::class);
    }
}