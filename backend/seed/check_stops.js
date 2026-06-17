require('dotenv').config();
const neo4j = require('neo4j-driver');
const driver = neo4j.driver(
  process.env.NEO4J_URI,
  neo4j.auth.basic(process.env.NEO4J_USERNAME, process.env.NEO4J_PASSWORD)
);
async function run() {
  const s = driver.session({ database: process.env.NEO4J_DATABASE });
  try {
    const r = await s.run(`
      MATCH (i:Itinerary)
      OPTIONAL MATCH (i)-[:HAS_STOP]->(st:ItineraryStop)
      OPTIONAL MATCH (st)-[:REFERS_TO]->(p:Place)
      RETURN i.id AS itinerario,
             count(DISTINCT st) AS tappe,
             count(DISTINCT p) AS luoghiCollegati
      ORDER BY i.id
    `);
    console.log('Itinerario -> tappe / luoghi collegati:');
    r.records.forEach(rec =>
      console.log(`  ${rec.get('itinerario')}: ${rec.get('tappe').toNumber()} tappe, ${rec.get('luoghiCollegati').toNumber()} luoghi`));
  } catch (e) { console.error(e.message); }
  finally { await s.close(); await driver.close(); }
}
run();