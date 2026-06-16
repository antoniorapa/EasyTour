/*
  Utility: genera l'hash bcrypt di una password.
  Uso:  node seed/genera_hash.js password123
  Copia l'hash stampato nel campo passwordHash dell'utente in Neo4j.
*/
const bcrypt = require('bcrypt');

const password = process.argv[2];

if (!password) {
  console.log('Uso: node seed/genera_hash.js <password>');
  process.exit(1);
}

bcrypt.hash(password, 10).then((hash) => {
  console.log(hash);
});