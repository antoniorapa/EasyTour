const neo4j = require("neo4j-driver");
require("dotenv").config();

const driver = neo4j.driver(
  process.env.NEO4J_URI,
  neo4j.auth.basic(
    process.env.NEO4J_USERNAME,
    process.env.NEO4J_PASSWORD
  )
);

async function verifyConnection() {
  try {
    await driver.verifyConnectivity();
    console.log("Connessione a Neo4j riuscita");
  } catch (error) {
    console.error("Errore connessione Neo4j:", error.message);
    process.exit(1);
  }
}

module.exports = {
  driver,
  verifyConnection
};