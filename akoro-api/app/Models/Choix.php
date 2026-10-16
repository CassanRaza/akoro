<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Choix extends Model
{
    use HasFactory;

    protected $table = 'choix';

    protected $fillable = ['question_id', 'texte', 'est_correct', 'ordre'];

    protected function casts(): array
    {
        return [
            'est_correct' => 'boolean',
        ];
    }

    public function question()
    {
        return $this->belongsTo(Question::class);
    }
}