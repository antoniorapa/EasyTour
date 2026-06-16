/*
  Seed Fase 0 (auth + dashboard) eseguito direttamente da Node.

  Si connette a Neo4j usando le credenziali del file .env
  (le stesse che usa il server) e crea:
   - i vincoli di unicità coerenti con lo schema esistente
   - il Comune di test Salerno con abbonamento attivo
   - un utente TURISTA  (turista@test.it / password123)
   - un utente OPERATORE_COMUNALE (comune@test.it / password123)

  Uso, dalla cartella backend/:
     node seed/seed_auth.js

  Lo script è idempotente: puoi rilanciarlo senza creare duplicati.
*/

require('dotenv').config();
const neo4j = require('neo4j-driver');
const bcrypt = require('bcrypt');

const PASSWORD_TEST = 'password123';

const driver = neo4j.driver(
  process.env.NEO4J_URI,
  neo4j.auth.basic(process.env.NEO4J_USERNAME, process.env.NEO4J_PASSWORD)
);

async function run() {
  const session = driver.session({ database: process.env.NEO4J_DATABASE });

  try {
    console.log('Connessione a Neo4j...');
    await driver.verifyConnectivity();
    console.log('Connessione riuscita.\n');

    // ---- Vincoli di unicità (idempotenti) ----
    const constraints = [
      'CREATE CONSTRAINT user_id IF NOT EXISTS FOR (u:User) REQUIRE u.id IS UNIQUE',
      'CREATE CONSTRAINT user_email IF NOT EXISTS FOR (u:User) REQUIRE u.email IS UNIQUE',
      'CREATE CONSTRAINT municipality_id IF NOT EXISTS FOR (m:Municipality) REQUIRE m.id IS UNIQUE',
      'CREATE CONSTRAINT subscription_id IF NOT EXISTS FOR (s:Subscription) REQUIRE s.id IS UNIQUE',
      'CREATE CONSTRAINT itinerary_id IF NOT EXISTS FOR (i:Itinerary) REQUIRE i.id IS UNIQUE',
      'CREATE CONSTRAINT report_id IF NOT EXISTS FOR (r:Report) REQUIRE r.id IS UNIQUE',
    ];

    for (const c of constraints) {
      await session.run(c);
    }
    console.log('Vincoli di unicità creati/verificati.');

    // ---- Comune di test con abbonamento attivo ----
    await session.run(`
      MERGE (m:Municipality {id: "comune_salerno"})
      SET m.nome = "Salerno",
          m.provincia = "SA",
          m.regione = "Campania",
          m.statoServizio = "ATTIVO",
          m.latitudine = 40.6824,
          m.longitudine = 14.7681
    `);

    await session.run(`
      MERGE (s:Subscription {id: "sub_salerno"})
      SET s.piano = "BASE",
          s.stato = "ATTIVO",
          s.metodoPagamento = "CARTA",
          s.dataInizio = date("2025-01-01"),
          s.dataFine = date("2026-12-31")
    `);

    await session.run(`
      MATCH (m:Municipality {id: "comune_salerno"})
      MATCH (s:Subscription {id: "sub_salerno"})
      MERGE (m)-[:HAS_SUBSCRIPTION]->(s)
    `);
    console.log('Comune Salerno + abbonamento attivo creati.');

    // ---- Hash della password di test ----
    const passwordHash = await bcrypt.hash(PASSWORD_TEST, 10);

    // ---- Utente TURISTA ----
    await session.run(
      `
      MERGE (t:User {id: "user_turista_test"})
      SET t.nome = "Mario Turista",
          t.email = "turista@test.it",
          t.passwordHash = $passwordHash,
          t.ruolo = "TURISTA"
      `,
      { passwordHash }
    );
    console.log('Utente TURISTA creato: turista@test.it / password123');

    // ---- Utente OPERATORE COMUNALE ----
    await session.run(
      `
      MERGE (o:User {id: "user_operatore_test"})
      SET o.nome = "Giulia Operatrice",
          o.email = "comune@test.it",
          o.passwordHash = $passwordHash,
          o.ruolo = "OPERATORE_COMUNALE",
          o.ruoloReferente = "Responsabile Turismo"
      `,
      { passwordHash }
    );

    await session.run(`
      MATCH (o:User {id: "user_operatore_test"})
      MATCH (m:Municipality {id: "comune_salerno"})
      MERGE (o)-[:MANAGES]->(m)
    `);
    console.log('Utente OPERATORE creato: comune@test.it / password123');

    console.log('\nSeed completato con successo.');
  } catch (error) {
    console.error('\nErrore durante il seed:', error.message);
    process.exitCode = 1;
  } finally {
    await session.close();
    await driver.close();
  }
}

run();
