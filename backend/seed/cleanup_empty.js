/*
  Elimina gli itinerari "vuoti" (senza tappe collegate).
  Un itinerario è vuoto se non ha alcuna relazione [:HAS_STOP].

  Sicuro: tocca SOLO gli Itinerary a 0 tappe e le loro relazioni
  CREATED / ASSOCIATED_TO. Non tocca Place, User, Municipality,
  né gli itinerari con tappe.

  Uso, da backend/:
     node seed/cleanup_empty.js          (mostra cosa eliminerebbe)
     node seed/cleanup_empty.js --conferma   (elimina davvero)
*/
require('dotenv').config();
const neo4j = require('neo4j-driver');

const driver = neo4j.driver(
  process.env.NEO4J_URI,
  neo4j.auth.basic(process.env.NEO4J_USERNAME, process.env.NEO4J_PASSWORD)
);

const conferma = process.argv.includes('--conferma');

async function run() {
  const session = driver.session({ database: process.env.NEO4J_DATABASE });
  try {
    // 1. Trova gli itinerari senza tappe
    const trova = await session.run(`
      MATCH (i:Itinerary)
      WHERE NOT (i)-[:HAS_STOP]->(:ItineraryStop)
      OPTIONAL MATCH (i)-[:ASSOCIATED_TO]->(m:Municipality)
      RETURN i.id AS id, m.id AS comune
      ORDER BY m.id, i.id
    `);

    if (trova.records.length === 0) {
      console.log('Nessun itinerario vuoto trovato. Niente da eliminare.');
      return;
    }

    console.log(`Itinerari vuoti trovati: ${trova.records.length}`);
    trova.records.forEach((r) =>
      console.log(`  ${r.get('comune') || '(senza comune)'} | ${r.get('id')}`)
    );

    if (!conferma) {
      console.log('\nQuesta è una ANTEPRIMA. Nessun dato è stato eliminato.');
      console.log('Per eliminare davvero, rilancia con:');
      console.log('   node seed/cleanup_empty.js --conferma');
      return;
    }

    // 2. Elimina gli itinerari vuoti e le loro relazioni (DETACH DELETE)
    const elimina = await session.run(`
      MATCH (i:Itinerary)
      WHERE NOT (i)-[:HAS_STOP]->(:ItineraryStop)
      DETACH DELETE i
      RETURN count(i) AS eliminati
    `);

    const n = elimina.records[0].get('eliminati');
    const eliminati = typeof n === 'object' && n.low !== undefined ? n.low : Number(n);
    console.log(`\nEliminati ${eliminati} itinerari vuoti.`);
  } catch (e) {
    console.error('Errore:', e.message);
    process.exitCode = 1;
  } finally {
    await session.close();
    await driver.close();
  }
}
run();