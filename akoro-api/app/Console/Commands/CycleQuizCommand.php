<?php

namespace App\Console\Commands;

use App\Services\CycleQuiz;
use Illuminate\Console\Command;

class CycleQuizCommand extends Command
{
    protected $signature = 'quiz:cycle';

    protected $description = 'Rappels 5 min avant les quiz, ouverture et passage automatique au statut « Terminé ».';

    public function handle(CycleQuiz $cycle): int
    {
        $cycle->synchroniser();

        return self::SUCCESS;
    }
}
