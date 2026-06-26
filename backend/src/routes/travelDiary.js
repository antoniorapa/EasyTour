const express = require("express");
const { v4: uuidv4 } = require("uuid");
const router = express.Router();
const multer = require("multer");
const path = require("path");

const { driver } = require("../db");
const { bucket } = require("../config/firebase");

// ─────────────────────────────────────────────────────────────
// Multer: memoria (il file va dritto a Firebase, non su disco)
// ─────────────────────────────────────────────────────────────
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const isImageMime = file.mimetype.startsWith("image/");
    const ext = path.extname(file.originalname).toLowerCase();
    const isImageExt = [".jpg", ".jpeg", ".png", ".webp", ".gif"].includes(ext);
    if (isImageMime || isImageExt) {
      cb(null, true);
    } else {
      cb(new Error("Il file non è un'immagine"));
    }
  },
});

// ─────────────────────────────────────────────────────────────
// GET diario di una tappa
// ─────────────────────────────────────────────────────────────
router.get("/stop/:stopId/user/:userId", async (req, res) => {
  const session = driver.session();
  try {
    const { stopId, userId } = req.params;
    const result = await session.run(
      `
      MATCH (u:User {id: $userId})
      OPTIONAL MATCH (u)-[:WROTE_DIARY_ENTRY]->(d:DiaryEntry {stopId: $stopId})
      OPTIONAL MATCH (u)-[:CREATED_REPORT]->(r:Report {stopId: $stopId})
      RETURN d, r
      ORDER BY r.dataCreazione DESC
      LIMIT 1
      `,
      { userId, stopId }
    );
    const record = result.records[0];
    const diaryNode = record?.get("d");
    const reportNode = record?.get("r");
    res.json({
      diary: diaryNode ? diaryNode.properties : null,
      report: reportNode ? reportNode.properties : null,
    });
  } catch (error) {
    console.error("Errore GET diario:", error);
    res.status(500).json({ error: "Errore durante il caricamento del diario" });
  } finally {
    await session.close();
  }
});

// ─────────────────────────────────────────────────────────────
// SAVE diario
// ─────────────────────────────────────────────────────────────
router.post("/save", async (req, res) => {
  const session = driver.session();
  try {
    const { userId, stopId, placeId, placeName, rating, note, photos } = req.body;
    if (!userId || !stopId) {
      return res.status(400).json({ error: "userId e stopId sono obbligatori" });
    }
    const result = await session.run(
      `
      MERGE (u:User {id: $userId})
      MERGE (d:DiaryEntry {userId: $userId, stopId: $stopId})
      ON CREATE SET
        d.id = $diaryId,
        d.dataCreazione = datetime()
      SET
        d.placeId = $placeId,
        d.placeName = $placeName,
        d.rating = $rating,
        d.note = $note,
        d.photos = $photos,
        d.dataAggiornamento = datetime()
      MERGE (u)-[:WROTE_DIARY_ENTRY]->(d)

      WITH d
      OPTIONAL MATCH (s:ItineraryStop {id: $stopId})
      FOREACH (_ IN CASE WHEN s IS NULL THEN [] ELSE [1] END |
        MERGE (d)-[:ABOUT_STOP]->(s)
      )

      WITH d
      OPTIONAL MATCH (p:Place {id: $placeId})
      FOREACH (_ IN CASE WHEN p IS NULL THEN [] ELSE [1] END |
        MERGE (d)-[:ABOUT_PLACE]->(p)
      )

      RETURN d
      `,
      {
        userId,
        stopId,
        placeId: placeId || "",
        placeName: placeName || "",
        rating: Number(rating || 0),
        note: note || "",
        photos: Array.isArray(photos) ? photos : [],
        diaryId: uuidv4(),
      }
    );
    const diary = result.records[0].get("d").properties;
    res.status(200).json({ message: "Diario salvato", diary });
  } catch (error) {
    console.error("Errore POST diario:", error);
    res.status(500).json({ error: "Errore durante il salvataggio del diario" });
  } finally {
    await session.close();
  }
});

// ─────────────────────────────────────────────────────────────
// UPLOAD FOTO → Firebase Storage + nodo (:Photo) collegato a (:DiaryEntry)
// Multipart form-data: photo=<file>, userId=<...>, stopId=<...>
// ─────────────────────────────────────────────────────────────
router.post("/upload-photo", upload.single("photo"), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "Nessun file ricevuto" });
  }

  const userId = req.body.userId;
  const stopId = req.body.stopId;

  if (!userId || !stopId) {
    return res
      .status(400)
      .json({ error: "userId e stopId sono obbligatori per collegare la foto" });
  }

  const session = driver.session();
  try {
    // 1) Verifica che esista il DiaryEntry dell'utente per quella tappa
    const check = await session.run(
      `
      MATCH (u:User {id: $userId})-[:WROTE_DIARY_ENTRY]->(d:DiaryEntry {stopId: $stopId})
      RETURN d
      LIMIT 1
      `,
      { userId, stopId }
    );

    if (check.records.length === 0) {
      return res.status(404).json({
        error:
          "DiaryEntry non trovato: salva prima il diario (POST /save) e poi carica le foto",
      });
    }

    // 2) Upload su Firebase Storage
    const ext = path.extname(req.file.originalname) || ".jpg";
    const storagePath = `diary/${userId}/${stopId}/${uuidv4()}${ext}`;
    const fileUpload = bucket.file(storagePath);
    const downloadToken = uuidv4();

    await fileUpload.save(req.file.buffer, {
      metadata: {
        contentType: req.file.mimetype,
        metadata: { firebaseStorageDownloadTokens: downloadToken },
      },
      resumable: false,
    });

    const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(
      storagePath
    )}?alt=media&token=${downloadToken}`;

    // 3) Crea il nodo (:Photo) e collegalo al (:DiaryEntry)
    const photoId = uuidv4();
    const created = await session.run(
      `
      MATCH (u:User {id: $userId})-[:WROTE_DIARY_ENTRY]->(d:DiaryEntry {stopId: $stopId})
      CREATE (ph:Photo {
        id: $photoId,
        url: $url,
        storagePath: $storagePath,
        contentType: $contentType,
        dataCreazione: datetime()
      })
      MERGE (d)-[:HAS_PHOTO]->(ph)
      RETURN ph
      `,
      {
        userId,
        stopId,
        photoId,
        url: publicUrl,
        storagePath,
        contentType: req.file.mimetype,
      }
    );

    const photo = created.records[0].get("ph").properties;

    res.status(201).json({
      message: "Foto caricata su Firebase e collegata alla tappa",
      photo: {
        id: photo.id,
        url: photo.url,
        contentType: photo.contentType,
      },
    });
  } catch (error) {
    console.error("Errore upload foto:", error);
    res.status(500).json({ error: "Errore durante il caricamento della foto" });
  } finally {
    await session.close();
  }
});

// ─────────────────────────────────────────────────────────────
// GET tutte le foto di una tappa (per visionarle nel diario)
// ─────────────────────────────────────────────────────────────
router.get("/stop/:stopId/user/:userId/photos", async (req, res) => {
  const session = driver.session();
  try {
    const { stopId, userId } = req.params;
    const result = await session.run(
      `
      MATCH (u:User {id: $userId})-[:WROTE_DIARY_ENTRY]->(d:DiaryEntry {stopId: $stopId})-[:HAS_PHOTO]->(ph:Photo)
      RETURN ph
      ORDER BY ph.dataCreazione ASC
      `,
      { userId, stopId }
    );
    const photos = result.records.map((rec) => {
      const ph = rec.get("ph").properties;
      return {
        id: ph.id,
        url: ph.url,
        contentType: ph.contentType,
        dataCreazione: ph.dataCreazione?.toString(),
      };
    });
    res.json({ photos });
  } catch (error) {
    console.error("Errore GET foto:", error);
    res.status(500).json({ error: "Errore durante il recupero delle foto" });
  } finally {
    await session.close();
  }
});

// ─────────────────────────────────────────────────────────────
// DELETE una foto (da Firebase Storage + da Neo4j)
// ─────────────────────────────────────────────────────────────
router.delete("/photo/:photoId/user/:userId", async (req, res) => {
  const session = driver.session();
  try {
    const { photoId, userId } = req.params;

    const result = await session.run(
      `
      MATCH (u:User {id: $userId})-[:WROTE_DIARY_ENTRY]->(:DiaryEntry)-[:HAS_PHOTO]->(ph:Photo {id: $photoId})
      RETURN ph.storagePath AS storagePath
      `,
      { userId, photoId }
    );

    if (result.records.length === 0) {
      return res.status(404).json({ error: "Foto non trovata o non autorizzato" });
    }

    const storagePath = result.records[0].get("storagePath");

    await bucket
      .file(storagePath)
      .delete()
      .catch((e) => console.warn("File già assente su Storage:", e.message));

    await session.run(`MATCH (ph:Photo {id: $photoId}) DETACH DELETE ph`, {
      photoId,
    });

    res.json({ message: "Foto eliminata" });
  } catch (error) {
    console.error("Errore DELETE foto:", error);
    res.status(500).json({ error: "Errore durante l'eliminazione della foto" });
  } finally {
    await session.close();
  }
});

// ─────────────────────────────────────────────────────────────
// REPORT segnalazione
// ─────────────────────────────────────────────────────────────
router.post("/report", async (req, res) => {
  const session = driver.session();
  try {
    const { userId, stopId, placeId, placeName, categoria, descrizione } = req.body;
    if (!userId || !stopId || !descrizione) {
      return res
        .status(400)
        .json({ error: "userId, stopId e descrizione sono obbligatori" });
    }
    const reportId = uuidv4();
    const result = await session.run(
      `
      MATCH (u:User {id: $userId})
      OPTIONAL MATCH (s:ItineraryStop {id: $stopId})<-[:HAS_STOP]-(:Itinerary)-[:ASSOCIATED_TO]->(mFromStop:Municipality)
      OPTIONAL MATCH (:Place {id: $placeId})-[:LOCATED_IN]->(mFromPlace:Municipality)
      WITH u, s, coalesce(mFromStop, mFromPlace) AS m
      CREATE (r:Report {
        id: $reportId,
        userId: $userId,
        stopId: $stopId,
        placeId: $placeId,
        placeName: $placeName,
        categoria: $categoria,
        descrizione: $descrizione,
        stato: "NUOVA",
        fonte: "DIARIO_VIAGGIO",
        municipalityId: CASE WHEN m IS NULL THEN null ELSE m.id END,
        dataCreazione: datetime()
      })
      MERGE (u)-[:CREATED_REPORT]->(r)
      WITH r, s, m
      FOREACH (_ IN CASE WHEN s IS NULL THEN [] ELSE [1] END |
        MERGE (r)-[:ABOUT_STOP]->(s)
      )
      WITH r, m
      OPTIONAL MATCH (p2:Place {id: $placeId})
      FOREACH (_ IN CASE WHEN p2 IS NULL THEN [] ELSE [1] END |
        MERGE (r)-[:ABOUT_PLACE]->(p2)
      )
      WITH r, m
      FOREACH (_ IN CASE WHEN m IS NULL THEN [] ELSE [1] END |
        MERGE (r)-[:FOR_MUNICIPALITY]->(m)
      )
      RETURN r
      `,
      {
        userId,
        stopId,
        placeId: placeId || "",
        placeName: placeName || "",
        categoria: categoria || "Altro",
        descrizione,
        reportId,
      }
    );
    const report = result.records[0].get("r").properties;
    res.status(201).json({ message: "Segnalazione creata", reportId, report });
  } catch (error) {
    console.error("Errore POST segnalazione:", error);
    res.status(500).json({ error: "Errore durante la creazione della segnalazione" });
  } finally {
    await session.close();
  }
});

// ─────────────────────────────────────────────────────────────
// DELETE segnalazione
// ─────────────────────────────────────────────────────────────
router.delete("/report/:reportId/user/:userId", async (req, res) => {
  const session = driver.session();
  try {
    const { reportId, userId } = req.params;
    const result = await session.run(
      `
      MATCH (u:User {id: $userId})-[:CREATED_REPORT]->(r:Report {id: $reportId})
      DETACH DELETE r
      RETURN count(r) AS deletedCount
      `,
      { reportId, userId }
    );
    const deletedCount = result.records[0].get("deletedCount").toNumber();
    if (deletedCount === 0) {
      return res.status(404).json({ error: "Segnalazione non trovata" });
    }
    res.json({ message: "Segnalazione eliminata" });
  } catch (error) {
    console.error("Errore DELETE segnalazione:", error);
    res.status(500).json({ error: "Errore durante l'eliminazione della segnalazione" });
  } finally {
    await session.close();
  }
});

module.exports = router;