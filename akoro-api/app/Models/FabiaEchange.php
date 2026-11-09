<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class FabiaEchange extends Model
{
    protected $table = 'fabia_echanges';

    protected $fillable = [
        'user_id',
        'etablissement_id',
        'question',
        'reponse',
        'categorie',
        'source',
        'langue',
        'masque',
    ];

    protected function casts(): array
    {
        return ['masque' => 'boolean'];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
