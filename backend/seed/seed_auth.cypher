// ============================================================
//  EasyTour - Seed Fase 0 (auth + dashboard)
//  Esegui questo script nella console di Neo4j Aura.
//
//  Crea:
//   - i vincoli di unicità (id) coerenti con lo schema esistente
//   - un Comune di test con abbonamento attivo (Salerno)
//   - un utente TURISTA e un utente OPERATORE_COMUNALE di test
//
//  NOTE IMPORTANTI:
//  - Le password qui sono GIA' hashate con bcrypt (vedi sotto).
//    Entrambi gli utenti di test hanno password in chiaro: "password123"
//  - Il label User e Municipality {id} sono gli stessi che usa
//    itineraries.js (MATCH (u:User {id}), MATCH (m:Municipality {id})),
//    quindi non rompiamo nulla di esistente.
// ============================================================

// ---- Vincoli di unicità (idempotenti) ----
CREATE CONSTRAINT user_id IF NOT EXISTS
FOR (u:User) REQUIRE u.id IS UNIQUE;

CREATE CONSTRAINT user_email IF NOT EXISTS
FOR (u:User) REQUIRE u.email IS UNIQUE;

CREATE CONSTRAINT municipality_id IF NOT EXISTS
FOR (m:Municipality) REQUIRE m.id IS UNIQUE;

CREATE CONSTRAINT subscription_id IF NOT EXISTS
FOR (s:Subscription) REQUIRE s.id IS UNIQUE;

CREATE CONSTRAINT itinerary_id IF NOT EXISTS
FOR (i:Itinerary) REQUIRE i.id IS UNIQUE;

CREATE CONSTRAINT report_id IF NOT EXISTS
FOR (r:Report) REQUIRE r.id IS UNIQUE;

// ---- Comune di test con abbonamento attivo ----
MERGE (m:Municipality {id: "comune_salerno"})
SET m.nome = "Salerno",
    m.provincia = "SA",
    m.regione = "Campania",
    m.statoServizio = "ATTIVO",
    m.latitudine = 40.6824,
    m.longitudine = 14.7681;

MERGE (s:Subscription {id: "sub_salerno"})
SET s.piano = "BASE",
    s.stato = "ATTIVO",
    s.metodoPagamento = "CARTA",
    s.dataInizio = date("2025-01-01"),
    s.dataFine = date("2026-12-31");

MATCH (m:Municipality {id: "comune_salerno"})
MATCH (s:Subscription {id: "sub_salerno"})
MERGE (m)-[:HAS_SUBSCRIPTION]->(s);

// ---- Utente TURISTA di test ----
// email: turista@test.it  |  password: password123
MERGE (t:User {id: "user_turista_test"})
SET t.nome = "Mario Turista",
    t.email = "turista@test.it",
    t.passwordHash = "$2b$10$d2sBS1P/I7fBG4cxTATv6OJHnTAGYmHSTX29y6DU/QfM1gUFRD/HK",
    t.ruolo = "TURISTA";

// ---- Utente OPERATORE COMUNALE di test ----
// email: comune@test.it  |  password: password123
MERGE (o:User {id: "user_operatore_test"})
SET o.nome = "Giulia Operatrice",
    o.email = "comune@test.it",
    o.passwordHash = "$2b$10$d2sBS1P/I7fBG4cxTATv6OJHnTAGYmHSTX29y6DU/QfM1gUFRD/HK",
    o.ruolo = "OPERATORE_COMUNALE",
    o.ruoloReferente = "Responsabile Turismo";

// L'operatore gestisce il proprio Comune
MATCH (o:User {id: "user_operatore_test"})
MATCH (m:Municipality {id: "comune_salerno"})
MERGE (o)-[:MANAGES]->(m);
