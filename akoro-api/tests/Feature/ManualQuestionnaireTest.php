<?php

namespace Tests\Feature;

use App\Models\Devoir;
use App\Models\Etablissement;
use App\Models\Parcours;
use App\Models\Question;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class ManualQuestionnaireTest extends TestCase
{
    private User $admin;

    private Devoir $devoir;

    protected function setUp(): void
    {
        parent::setUp();

        $this->createQuestionnaireSchema();
        $etablissement = Etablissement::create(['nom' => 'FabLab Test']);
        $parcours = Parcours::create([
            'etablissement_id' => $etablissement->id,
            'nom' => 'Parcours Test',
        ]);
        $this->admin = User::factory()->create([
            'etablissement_id' => $etablissement->id,
            'role' => 'fabmanager',
        ]);
        $this->devoir = Devoir::create([
            'etablissement_id' => $etablissement->id,
            'parcours_id' => $parcours->id,
            'created_by' => $this->admin->id,
            'type' => 'qcm',
            'titre' => 'Questionnaire de test',
            'statut' => 'brouillon',
        ]);
    }

    protected function tearDown(): void
    {
        Schema::disableForeignKeyConstraints();
        foreach (['choix', 'questions', 'devoirs', 'users', 'parcours', 'etablissements'] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::enableForeignKeyConstraints();

        parent::tearDown();
    }

    public function test_manual_questionnaire_saves_at_least_five_questions_and_three_choices_each(): void
    {
        $response = $this->actingAs($this->admin, 'sanctum')
            ->postJson("/api/devoirs/{$this->devoir->id}/questions", [
                'questions' => $this->questionnaire(5),
            ]);

        $response->assertOk()
            ->assertJsonCount(5, 'questions');
        $this->assertDatabaseCount('questions', 5);
        $this->assertDatabaseCount('choix', 15);
        $this->assertSame(
            [1, 2, 3, 4, 5],
            array_column($response->json('questions'), 'ordre')
        );
    }

    public function test_manual_questionnaire_rejects_fewer_than_five_without_saving_any(): void
    {
        $response = $this->actingAs($this->admin, 'sanctum')
            ->postJson("/api/devoirs/{$this->devoir->id}/questions", [
                'questions' => $this->questionnaire(4),
            ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors('questions');
        $this->assertDatabaseCount('questions', 0);
        $this->assertDatabaseCount('choix', 0);
    }

    public function test_manual_questionnaire_rejects_questions_with_multiple_correct_answers(): void
    {
        $questions = $this->questionnaire(5);
        $questions[2]['choix'][1]['est_correct'] = true;

        $response = $this->actingAs($this->admin, 'sanctum')
            ->postJson("/api/devoirs/{$this->devoir->id}/questions", [
                'questions' => $questions,
            ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors('questions.2.choix');
        $this->assertDatabaseCount('questions', 0);
        $this->assertDatabaseCount('choix', 0);
    }

    public function test_manual_questionnaire_appends_in_order_after_existing_questions(): void
    {
        Question::create([
            'devoir_id' => $this->devoir->id,
            'enonce' => 'Question déjà existante ?',
            'ordre' => 4,
            'points' => 1,
        ]);

        $response = $this->actingAs($this->admin, 'sanctum')
            ->postJson("/api/devoirs/{$this->devoir->id}/questions", [
                'questions' => $this->questionnaire(5),
            ]);

        $response->assertOk();
        $this->assertSame(
            [4, 5, 6, 7, 8, 9],
            array_column($response->json('questions'), 'ordre')
        );
    }

    private function questionnaire(int $count): array
    {
        return array_map(static fn (int $index): array => [
            'enonce' => "Question numéro {$index} ?",
            'points' => 1,
            'choix' => [
                ['texte' => "Réponse correcte {$index}", 'est_correct' => true],
                ['texte' => "Réponse incorrecte A {$index}", 'est_correct' => false],
                ['texte' => "Réponse incorrecte B {$index}", 'est_correct' => false],
            ],
        ], range(1, $count));
    }

    private function createQuestionnaireSchema(): void
    {
        Schema::create('etablissements', function (Blueprint $table): void {
            $table->id();
            $table->string('nom');
            $table->timestamps();
        });

        Schema::create('parcours', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('etablissement_id')->constrained();
            $table->string('nom');
            $table->timestamps();
        });

        Schema::create('users', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('etablissement_id')->nullable()->constrained();
            $table->string('role')->default('beneficiaire');
            $table->string('name');
            $table->string('email')->unique();
            $table->timestamp('email_verified_at')->nullable();
            $table->string('password');
            $table->rememberToken();
            $table->timestamps();
        });

        Schema::create('devoirs', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('etablissement_id')->constrained();
            $table->foreignId('parcours_id')->constrained();
            $table->foreignId('created_by')->constrained('users');
            $table->string('type');
            $table->string('titre');
            $table->text('description')->nullable();
            $table->dateTime('date_debut')->nullable();
            $table->unsignedInteger('duree_minutes')->nullable();
            $table->dateTime('date_limite')->nullable();
            $table->string('fichier_consigne')->nullable();
            $table->string('statut')->default('brouillon');
            $table->timestamps();
        });

        Schema::create('questions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('devoir_id')->constrained()->cascadeOnDelete();
            $table->text('enonce');
            $table->unsignedInteger('ordre')->default(1);
            $table->unsignedInteger('points')->default(1);
            $table->timestamps();
        });

        Schema::create('choix', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('question_id')->constrained()->cascadeOnDelete();
            $table->string('texte');
            $table->boolean('est_correct')->default(false);
            $table->unsignedInteger('ordre')->default(1);
            $table->timestamps();
        });
    }
}
