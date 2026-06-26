const { initializeApp, getApps, getApp, cert } = require("firebase-admin/app");
const { getStorage } = require("firebase-admin/storage");
const path = require("path");

const serviceAccount = require(path.join(__dirname, "serviceAccountKey.json"));

const bucketName =
  process.env.FIREBASE_STORAGE_BUCKET || "easy-tour-88842.firebasestorage.app";

const app = getApps().length
  ? getApp()
  : initializeApp({
      credential: cert(serviceAccount),
      storageBucket: bucketName,
    });

const bucket = getStorage(app).bucket();

console.log("[firebase] inizializzato. Bucket:", bucket && bucket.name);

module.exports = { bucket };