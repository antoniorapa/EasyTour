/*
  Pulisce i Place fantasma chiamati "Luogo senza nome" (creati prima
  del fix di itinerary_stop.dart) e i loro ItineraryStop.
  Poi elimina anche gli itinerari che restano senza tappe.

  Uso, da backend/:
     node seed/cleanup_noname.js           (anteprima)
     node seed/cleanup_noname.js --conferma (elimina)
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
    // Anteprima: quanti Place fantasma e stop collegati
    const prev = await session.run(`
      MATCH (p:Place {nome: "Luogo senza nome"})
      OPTIONAL MATCH (s:ItineraryStop)-[:REFERS_TO]->(p)
      RETURN count(DISTINCT p) AS places, count(DISTINCT s) AS stops
    `);
    const places = prev.records[0].get('places');
    const stops = prev.records[0].get('stops');
    const nPlaces = typeof places === 'object' ? places.low : Number(places);
    const nStops = typeof stops === 'object' ? stops.low : Number(stops);

    console.log(`Place "Luogo senza nome" trovati: ${nPlaces}`);
    console.log(`ItineraryStop collegati a questi Place: ${nStops}`);

    if (nPlaces === 0) {
      console.log('Niente da pulire.');
      return;
    }

    if (!conferma) {
      console.log('\nANTEPRIMA. Niente eliminato.');
      console.log('Per eliminare: node seed/cleanup_noname.js --conferma');
      return;
    }

    // 1. Elimina gli stop che puntano ai Place fantasma + i Place stessi
    await session.run(`
      MATCH (p:Place {nome: "Luogo senza nome"})
      OPTIONAL MATCH (s:ItineraryStop)-[:REFERS_TO]->(p)
      DETACH DELETE s, p
    `);
    console.log('\nEliminati Place fantasma e relativi stop.');

    // 2. Elimina gli itinerari rimasti senza tappe
    const empty = await session.run(`
      MATCH (i:Itinerary)
      WHERE NOT (i)-[:HAS_STOP]->(:ItineraryStop)
      DETACH DELETE i
      RETURN count(i) AS eliminati
    `);
    const e = empty.records[0].get('eliminati');
    const nEmpty = typeof e === 'object' ? e.low : Number(e);
    console.log(`Eliminati ${nEmpty} itinerari rimasti senza tappe.`);
    console.log('\nPulizia completata.');
  } catch (e) {
    console.error('Errore:', e.message);
    process.exitCode = 1;
  } finally {
    await session.close();
    await driver.close();
  }
}
run();
