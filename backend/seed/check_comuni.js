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
      MATCH (i:Itinerary)-[:ASSOCIATED_TO]->(m:Municipality)
      OPTIONAL MATCH (i)-[:HAS_STOP]->(st:ItineraryStop)
      RETURN m.id AS comune, i.id AS itinerario, count(st) AS tappe
      ORDER BY m.id, i.id
    `);
    r.records.forEach(rec =>
      console.log(`${rec.get('comune')} | ${rec.get('itinerario')} | ${rec.get('tappe').toNumber()} tappe`));
  } catch (e) { console.error(e.message); }
  finally { await s.close(); await driver.close(); }
}
run();