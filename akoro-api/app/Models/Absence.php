<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Absence extends Model
{
    use HasFactory;

    // non_justifiee : créée automatiquement | a_valider : motif envoyé par le bénéficiaire
    // justifiee / refusee : décision du FabManager
    public const STATUTS = ['non_justifiee', 'a_valider', 'justifiee', 'refusee'];

    protected $fillable = ['user_id', 'lecon_id', 'seance_id', 'date', 'motif', 'statut'];

    protected function casts(): array
    {
        return [
            'date' => 'date:Y-m-d',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function lecon()
    {
        return $this->belongsTo(Lecon::class);
    }

    public function seance()
    {
        return $this->belongsTo(Seance::class);
    }
}