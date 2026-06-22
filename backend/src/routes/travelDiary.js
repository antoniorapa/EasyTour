const express = require("express");
const { v4: uuidv4 } = require("uuid");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");

const { driver } = require('../db');

const uploadDir = path.join(__dirname, "..", "uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || ".jpg";
    cb(null, `${uuidv4()}${ext}`);
  },
});

const upload = multer({
  storage,
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

router.post("/save", async (req, res) => {
  const session = driver.session();

  try {
    const { userId, stopId, placeId, placeName, rating, note, photos } = req.body;

    if (!userId || !stopId) {
      return res.status(400).json({
        error: "userId e stopId sono obbligatori",
      });
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

    res.status(200).json({
      message: "Diario salvato",
      diary,
    });
  } catch (error) {
    console.error("Errore POST diario:", error);
    res.status(500).json({ error: "Errore durante il salvataggio del diario" });
  } finally {
    await session.close();
  }
});

router.post("/report", async (req, res) => {
  const session = driver.session();

  try {
    const {
      userId,
      stopId,
      placeId,
      placeName,
      categoria,
      descrizione,
    } = req.body;

    if (!userId || !stopId || !descrizione) {
      return res.status(400).json({
        error: "userId, stopId e descrizione sono obbligatori",
      });
    }

    const reportId = uuidv4();

    const result = await session.run(
      `
      MATCH (u:User {id: $userId})

      // Comune ricavato dalla tappa -> itinerario
      OPTIONAL MATCH (s:ItineraryStop {id: $stopId})<-[:HAS_STOP]-(:Itinerary)-[:ASSOCIATED_TO]->(mFromStop:Municipality)

      // Fallback: dal Place, se esiste nel grafo
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

    res.status(201).json({
      message: "Segnalazione creata",
      reportId,
      report,
    });
  } catch (error) {
    console.error("Errore POST segnalazione:", error);
    res.status(500).json({ error: "Errore durante la creazione della segnalazione" });
  } finally {
    await session.close();
  }
});

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
      return res.status(404).json({
        error: "Segnalazione non trovata",
      });
    }

    res.json({
      message: "Segnalazione eliminata",
    });
  } catch (error) {
    console.error("Errore DELETE segnalazione:", error);
    res.status(500).json({ error: "Errore durante l’eliminazione della segnalazione" });
  } finally {
    await session.close();
  }
});

router.post("/upload-photo", upload.single("photo"), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "Nessun file ricevuto" });
  }

  // URL relativo: il client lo combina con baseUrl
  const relativeUrl = `/uploads/${req.file.filename}`;

  res.status(201).json({
    message: "Foto caricata",
    url: relativeUrl,
  });
});

module.exports = router;