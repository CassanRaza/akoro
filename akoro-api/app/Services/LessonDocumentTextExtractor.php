<?php

namespace App\Services;

use App\Models\Ressource;
use DOMDocument;
use DOMXPath;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Symfony\Component\Process\Exception\ProcessStartFailedException;
use Symfony\Component\Process\Exception\ProcessTimedOutException;
use Symfony\Component\Process\Process;

class LessonDocumentTextExtractor
{
    public function extract(Ressource $ressource): string
    {
        $path = Storage::disk('local')->path($ressource->chemin);
        if (! is_file($path)) {
            throw new RuntimeException(
                "Le fichier « {$ressource->nom_fichier} » est introuvable sur le serveur."
            );
        }

        $extension = strtolower(pathinfo($ressource->nom_fichier, PATHINFO_EXTENSION));
        $text = match ($extension) {
            'pdf' => $this->extractPdf($path, $ressource->nom_fichier),
            'docx' => $this->extractWordXml($path, 'word/document.xml', $ressource->nom_fichier),
            'odt' => $this->extractOdt($path, $ressource->nom_fichier),
            'pptx' => $this->extractPowerPoint($path, $ressource->nom_fichier),
            'xlsx' => $this->extractExcel($path, $ressource->nom_fichier),
            'txt', 'csv' => $this->readTextFile($path),
            'rtf' => $this->extractRtf($path),
            default => throw new RuntimeException(
                "Le format « .{$extension} » de « {$ressource->nom_fichier} » ne peut pas être lu pour générer des questions. "
                .'Convertissez-le en PDF, DOCX, PPTX, XLSX, ODT, RTF ou TXT.'
            ),
        };

        $text = $this->normalize($text);
        if ($text === '') {
            throw new RuntimeException(
                "Aucun texte n’a pu être extrait de « {$ressource->nom_fichier} ». "
                .'Si le PDF est un scan ou si le fichier contient uniquement des images, ajoutez une version avec texte sélectionnable.'
            );
        }

        return $text;
    }

    private function extractPdf(string $path, string $fileName): string
    {
        $binary = config('services.question_documents.pdftotext_binary', 'pdftotext');
        $process = new Process([$binary, '-enc', 'UTF-8', '-layout', $path, '-']);
        $process->setTimeout(60);
        try {
            $process->run();
        } catch (ProcessStartFailedException $exception) {
            throw new RuntimeException(
                'La lecture PDF est indisponible : installez Poppler (pdftotext) sur le serveur API '
                .'ou définissez PDFTOTEXT_BINARY dans akoro-api/.env.',
                previous: $exception
            );
        } catch (ProcessTimedOutException $exception) {
            throw new RuntimeException(
                "La lecture du PDF « {$fileName} » a dépassé le délai autorisé.",
                previous: $exception
            );
        }

        if (! $process->isSuccessful()) {
            throw new RuntimeException(
                "Impossible de lire le PDF « {$fileName} ». Vérifiez que pdftotext (Poppler) est installé sur le serveur API."
            );
        }

        return $process->getOutput();
    }

    private function extractWordXml(string $path, string $entry, string $fileName): string
    {
        $xml = $this->readArchiveEntry($path, $entry, $fileName);
        $xpath = $this->xpath($xml, $fileName);
        $paragraphs = [];

        foreach ($xpath->query('//*[local-name()="p"]') as $paragraph) {
            $text = trim($paragraph->textContent);
            if ($text !== '') {
                $paragraphs[] = $text;
            }
        }

        return implode("\n", $paragraphs);
    }

    private function extractOdt(string $path, string $fileName): string
    {
        $xml = $this->readArchiveEntry($path, 'content.xml', $fileName);
        $xpath = $this->xpath($xml, $fileName);
        $paragraphs = [];

        foreach ($xpath->query('//*[local-name()="p" or local-name()="h"]') as $paragraph) {
            $text = trim($paragraph->textContent);
            if ($text !== '') {
                $paragraphs[] = $text;
            }
        }

        return implode("\n", $paragraphs);
    }

    private function extractPowerPoint(string $path, string $fileName): string
    {
        $slides = [];
        for ($index = 1; $index <= 500; $index++) {
            $entry = "ppt/slides/slide{$index}.xml";
            $xml = $this->readArchiveEntry($path, $entry, $fileName, false);
            if ($xml === null) {
                if ($index === 1) {
                    throw new RuntimeException(
                        "Aucune diapositive lisible n’a été trouvée dans « {$fileName} »."
                    );
                }
                break;
            }

            $xpath = $this->xpath($xml, $fileName);
            foreach ($xpath->query('//*[local-name()="sp"]') as $shape) {
                $paragraphs = [];
                foreach ($xpath->query('.//*[local-name()="p"]', $shape) as $paragraph) {
                    $text = trim($paragraph->textContent);
                    if ($text !== '') {
                        $paragraphs[] = $text;
                    }
                }
                if ($paragraphs !== []) {
                    $slides[] = implode(' ', $paragraphs);
                }
            }
        }

        return implode("\n", $slides);
    }

    private function extractExcel(string $path, string $fileName): string
    {
        $sharedStringsXml = $this->readArchiveEntry($path, 'xl/sharedStrings.xml', $fileName, false);
        $sharedStrings = [];
        if ($sharedStringsXml !== null) {
            $xpath = $this->xpath($sharedStringsXml, $fileName);
            foreach ($xpath->query('//*[local-name()="si"]') as $item) {
                $sharedStrings[] = trim($item->textContent);
            }
        }

        $sheets = [];
        for ($index = 1; $index <= 100; $index++) {
            $xml = $this->readArchiveEntry($path, "xl/worksheets/sheet{$index}.xml", $fileName, false);
            if ($xml === null) {
                if ($index === 1) {
                    throw new RuntimeException(
                        "Aucune feuille lisible n’a été trouvée dans « {$fileName} »."
                    );
                }
                break;
            }

            $xpath = $this->xpath($xml, $fileName);
            foreach ($xpath->query('//*[local-name()="row"]') as $row) {
                $cells = [];
                foreach ($xpath->query('./*[local-name()="c"]', $row) as $cell) {
                    $value = trim($cell->textContent);
                    if ($cell->getAttribute('t') === 's' && ctype_digit($value)) {
                        $value = $sharedStrings[(int) $value] ?? '';
                    }
                    if ($value !== '') {
                        $cells[] = $value;
                    }
                }
                if ($cells !== []) {
                    $sheets[] = implode(' | ', $cells);
                }
            }
        }

        return implode("\n", $sheets);
    }

    private function readArchiveEntry(
        string $path,
        string $entry,
        string $fileName,
        bool $required = true
    ): ?string {
        $archivePath = realpath($path);
        $contents = $archivePath === false
            ? false
            : @file_get_contents('phar://'.$archivePath.'/'.$entry);

        if ($contents === false && $required) {
            throw new RuntimeException(
                "Le document « {$fileName} » est illisible ou incomplet (contenu « {$entry} » introuvable)."
            );
        }

        return $contents === false ? null : $contents;
    }

    private function xpath(string $xml, string $fileName): DOMXPath
    {
        $document = new DOMDocument();
        $previous = libxml_use_internal_errors(true);
        $loaded = $document->loadXML($xml, LIBXML_NONET | LIBXML_NOBLANKS);
        libxml_clear_errors();
        libxml_use_internal_errors($previous);

        if (! $loaded) {
            throw new RuntimeException(
                "Le contenu du document « {$fileName} » est endommagé ou ne peut pas être analysé."
            );
        }

        return new DOMXPath($document);
    }

    private function readTextFile(string $path): string
    {
        $text = file_get_contents($path);
        if ($text === false) {
            throw new RuntimeException('Impossible de lire le fichier texte de la leçon.');
        }

        return $text;
    }

    private function extractRtf(string $path): string
    {
        $content = $this->readTextFile($path);
        $content = preg_replace_callback(
            '/\\\\\'([0-9a-f]{2})/i',
            static fn (array $match) => chr(hexdec($match[1])),
            $content
        );
        $content = preg_replace('/\\\\(?:par|line)\b\s?/i', "\n", $content);
        $content = preg_replace('/\\\\[a-z]+\d* ?/i', '', $content);
        $content = str_replace(['\\{', '\\}', '\\\\'], ['{', '}', '\\'], $content);

        return preg_replace('/[{}]/', '', $content);
    }

    private function normalize(string $text): string
    {
        $text = iconv('UTF-8', 'UTF-8//IGNORE', $text) ?: '';
        $text = preg_replace('/[\t \x{00A0}]+/u', ' ', $text) ?? '';
        $text = preg_replace('/ *\R */u', "\n", $text) ?? '';
        $text = preg_replace('/\n{3,}/u', "\n\n", $text) ?? '';

        return trim($text);
    }
}
