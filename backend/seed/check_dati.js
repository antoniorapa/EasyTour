require('dotenv').config();
const neo4j = require('neo4j-driver');

const driver = neo4j.driver(
  process.env.NEO4J_URI,
  neo4j.auth.basic(process.env.NEO4J_USERNAME, process.env.NEO4J_PASSWORD)
);

async function run() {
  const session = driver.session({ database: process.env.NEO4J_DATABASE });
  try {
    const r = await session.run(`MATCH (i:Itinerary) RETURN count(i) AS tot`);
    console.log('Itinerari salvati:', r.records[0].get('tot').toNumber());

    const f = await session.run(`
      MATCH (i:Itinerary)
      RETURN DISTINCT i.filterType AS filtro, count(*) AS quanti
    `);
    console.log('\nFiltri usati (campo filterType):');
    if (f.records.length === 0) console.log('  (nessun itinerario)');
    else f.records.forEach(rec =>
      console.log(`  ${rec.get('filtro')} -> ${rec.get('quanti').toNumber()}`));

    const p = await session.run(`MATCH (p:Place) RETURN count(p) AS tot`);
    console.log('\nLuoghi (Place):', p.records[0].get('tot').toNumber());

    // Verifica relazioni che servono alla dashboard
    const rel = await session.run(`
      MATCH (i:Itinerary)-[:ASSOCIATED_TO]->(m:Municipality)
      RETURN m.id AS comune, count(i) AS itinerari
    `);
    console.log('\nItinerari per Comune:');
    if (rel.records.length === 0) console.log('  (nessuna relazione ASSOCIATED_TO)');
    else rel.records.forEach(rec =>
      console.log(`  ${rec.get('comune')} -> ${rec.get('itinerari').toNumber()}`));

    // Esempio proprietà di un Place
    const ex = await session.run(`MATCH (p:Place) RETURN p LIMIT 1`);
    if (ex.records.length > 0) {
      console.log('\nEsempio proprietà Place:', Object.keys(ex.records[0].get('p').properties));
    }
  } catch (e) {
    console.error('Errore:', e.message);
  } finally {
    await session.close();
    await driver.close();
  }
}
run();