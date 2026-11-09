<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Un chapitre (document d'une leçon) terminé par un bénéficiaire. */
class Progression extends Model
{
    protected $fillable = ['user_id', 'lecon_id', 'ressource_id', 'termine_le'];

    protected function casts(): array
    {
        return ['termine_le' => 'datetime'];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function lecon()
    {
        return $this->belongsTo(Lecon::class);
    }

    public function ressource()
    {
        return $this->belongsTo(Ressource::class);
    }
}
