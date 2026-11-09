<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Presence extends Model
{
    use HasFactory;

    protected $fillable = ['user_id', 'seance_id', 'date', 'heure_arrivee', 'heure_depart', 'mode'];

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

    // Séance dont le QR a été scanné (null pour les anciens pointages)
    public function seance()
    {
        return $this->belongsTo(Seance::class);
    }
}