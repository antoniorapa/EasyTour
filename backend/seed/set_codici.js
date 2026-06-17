/*
  Assegna un codiceAttivazione a ogni Municipality che non ne ha uno.
  Stampa i codici così puoi comunicarli a chi deve registrarsi.

  A Salerno (comune di test) assegna un codice fisso noto: SAL-2026
  Agli altri Comuni un codice casuale.

  Uso, da backend/:
     node seed/set_codici.js
*/
require('dotenv').config();
const neo4j = require('neo4j-driver');
const crypto = require('crypto');

const driver = neo4j.driver(
  process.env.NEO4J_URI,
  neo4j.auth.basic(process.env.NEO4J_USERNAME, process.env.NEO4J_PASSWORD)
);

function generaCodice() {
  // Codice tipo "AB12-CD34"
  return crypto.randomBytes(4).toString('hex').toUpperCase().replace(/(.{4})/, '$1-');
}

async function run() {
  const session = driver.session({ database: process.env.NEO4J_DATABASE });
  try {
    const result = await session.run(`MATCH (m:Municipality) RETURN m.id AS id, m.nome AS nome, m.codiceAttivazione AS codice`);

    console.log('Codici di attivazione dei Comuni:\n');

    for (const rec of result.records) {
      const id = rec.get('id');
      const nome = rec.get('nome');
      let codice = rec.get('codice');

      if (!codice) {
        // Salerno: codice fisso per i test. Altri: casuale.
        codice = id === 'comune_salerno' ? 'SAL-2026' : generaCodice();
        await session.run(
          `MATCH (m:Municipality {id: $id}) SET m.codiceAttivazione = $codice`,
          { id, codice }
        );
        console.log(`  ${nome} (${id}): ${codice}  [ASSEGNATO ORA]`);
      } else {
        console.log(`  ${nome} (${id}): ${codice}  [già presente]`);
      }
    }

    console.log('\nComunica questi codici a chi deve registrarsi come operatore.');
  } catch (e) {
    console.error('Errore:', e.message);
    process.exitCode = 1;
  } finally {
    await session.close();
    await driver.close();
  }
}
run();
