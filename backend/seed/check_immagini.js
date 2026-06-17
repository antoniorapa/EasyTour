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
      MATCH (p:Place)
      RETURN p.nome AS nome,
             p.immagineUrl AS immagineUrl,
             p.photoName AS photoName,
             p.photoReference AS photoReference
      ORDER BY p.nome
    `);
    r.records.forEach(rec => {
      const img = rec.get('immagineUrl');
      const pn = rec.get('photoName');
      const pr = rec.get('photoReference');
      console.log(`${rec.get('nome')}`);
      console.log(`   immagineUrl: ${img ? img.substring(0,60) : '(vuoto)'}`);
      console.log(`   photoName: ${pn ? 'presente' : '(vuoto)'} | photoReference: ${pr ? 'presente' : '(vuoto)'}`);
    });
  } catch (e) { console.error(e.message); }
  finally { await s.close(); await driver.close(); }
}
run();
