<?php

namespace App\Console\Commands;

use App\Services\AbsenceGenerator;
use Illuminate\Console\Command;

class GenererAbsences extends Command
{
    protected $signature = 'absences:generer';

    protected $description = 'Crée les absences des séances terminées (bénéficiaires sans pointage).';

    public function handle(AbsenceGenerator $generator): int
    {
        $nombre = $generator->generer();
        $this->info("{$nombre} absence(s) créée(s).");

        return self::SUCCESS;
    }
}