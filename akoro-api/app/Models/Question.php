<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Question extends Model
{
    use HasFactory;

    protected $fillable = ['devoir_id', 'enonce', 'ordre', 'points'];

    public function devoir()
    {
        return $this->belongsTo(Devoir::class);
    }

    public function choix()
    {
        return $this->hasMany(Choix::class)->orderBy('ordre');
    }
}