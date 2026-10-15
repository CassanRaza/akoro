<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Reponse extends Model
{
    use HasFactory;

    protected $fillable = [
        'resultat_quiz_id',
        'question_id',
        'choix_id',
        'est_correcte',
    ];

    protected function casts(): array
    {
        return [
            'est_correcte' => 'boolean',
        ];
    }

    public function resultat()
    {
        return $this->belongsTo(ResultatQuiz::class, 'resultat_quiz_id');
    }

    public function question()
    {
        return $this->belongsTo(Question::class);
    }

    public function choix()
    {
        return $this->belongsTo(Choix::class);
    }
}