<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Conversation extends Model
{
    use HasFactory;

    public const TYPES = ['privee', 'groupe_parcours', 'groupe_general'];

    protected $fillable = [
        'etablissement_id',
        'parcours_id',
        'type',
        'nom',
    ];

    public function etablissement()
    {
        return $this->belongsTo(Etablissement::class);
    }

    public function parcours()
    {
        return $this->belongsTo(Parcours::class);
    }

    public function users()
    {
        return $this->belongsToMany(User::class)
            ->withPivot('last_read_at')
            ->withTimestamps();
    }

    public function messages()
    {
        return $this->hasMany(Message::class)->orderBy('created_at');
    }

    public function dernierMessage()
    {
        return $this->hasOne(Message::class)->latestOfMany();
    }
}