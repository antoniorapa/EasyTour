const express = require("express");
const cors = require("cors");
require("dotenv").config();

const placesRoutes = require("./routes/places");
const municipalityRoutes = require("./routes/municipality");
const itinerariesRoutes = require("./routes/itineraries");
const googlePlacesRoutes = require("./routes/googlePlaces");
const wikiRoutes = require("./routes/wiki");
const authRoutes = require("./routes/auth");
const dashboardRoutes = require("./routes/dashboard_comune");

const { verifyConnection } = require("./db");

const app = express();

app.use(cors());
app.use(express.json());

// ─────────────────────────────────────────────────────────────
// Rotta base
// ─────────────────────────────────────────────────────────────

app.get("/", (req, res) => {
  res.json({
    message: "EasyTour backend attivo",
    routes: {
      auth: "/auth",
      places: "/places",
      municipality: "/municipality",
      itineraries: "/itineraries",
      googlePlaces: "/google/places",
      wiki: "/wiki",
      dashboard: "/dashboard",
    },
  });
});

// ─────────────────────────────────────────────────────────────
// Rotte principali
// ─────────────────────────────────────────────────────────────

app.use("/auth", authRoutes);
app.use("/places", placesRoutes);
app.use("/municipality", municipalityRoutes);
app.use("/itineraries", itinerariesRoutes);
app.use("/google/places", googlePlacesRoutes);
app.use("/wiki", wikiRoutes);
app.use("/dashboard", dashboardRoutes);

// ─────────────────────────────────────────────────────────────
// Debug endpoint rotte
// ─────────────────────────────────────────────────────────────

app.get("/debug/routes", (req, res) => {
  res.json({
    message: "Rotte principali EasyTour",
    endpoints: {
      login: "POST /auth/login",
      registerTourist: "POST /auth/register/tourist",
      registerMunicipality: "POST /auth/register/municipality",

      searchMunicipality: "GET /municipality/search?q=roma",
      checkMunicipalityPoint: "GET /municipality/check-point?lat=...&lng=...",
      municipalityStatus: "GET /municipality/:municipalityId/status",

      placesByMunicipality: "GET /places/:municipalityId",
      placesByRadius: "GET /places/:municipalityId/radius/:radiusKm",

      generateItinerary: "POST /itineraries/generate",
      saveItinerary: "POST /itineraries/save",
      userItineraries: "GET /itineraries/user/:userId",

      googleNearby: "GET /google/places/nearby?lat=...&lng=...&radiusKm=...",
      googleTextSearch: "GET /google/places/text-search?q=...",
      googleDetail: "GET /google/places/detail/:placeId",
      googlePhoto: "GET /google/places/photo?name=...&maxWidthPx=800",

      wikiSummary: "GET /wiki/summary?q=...",
      wikiImages: "GET /wiki/images?q=...",

      dashboardSummary: "GET /dashboard/summary",
      dashboardTopPlaces: "GET /dashboard/top-places",
      dashboardPlacesToImprove: "GET /dashboard/places-to-improve",
      dashboardFilters: "GET /dashboard/filters",
      dashboardReports: "GET /dashboard/reports",
    },
  });
});

// ─────────────────────────────────────────────────────────────
// Test Neo4j
// ─────────────────────────────────────────────────────────────

app.get("/test-neo4j", async (req, res) => {
  const { driver } = require("./db");
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  try {
    const result = await session.run(
      'RETURN "Connessione Neo4j funzionante" AS messaggio'
    );

    res.json({
      success: true,
      message: result.records[0].get("messaggio"),
      database: process.env.NEO4J_DATABASE || "default",
    });
  } catch (error) {
    console.error("Errore test Neo4j:", error);

    res.status(500).json({
      success: false,
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

// ─────────────────────────────────────────────────────────────
// Gestione 404
// ─────────────────────────────────────────────────────────────

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Endpoint non trovato",
    method: req.method,
    path: req.originalUrl,
  });
});

// ─────────────────────────────────────────────────────────────
// Start server
// ─────────────────────────────────────────────────────────────

const PORT = process.env.PORT || 3000;

verifyConnection()
  .then(() => {
    app.listen(PORT, "0.0.0.0", () => {
      console.log(`Server avviato sulla porta ${PORT}`);
      console.log(`Home: http://localhost:${PORT}`);
      console.log(`Debug routes: http://localhost:${PORT}/debug/routes`);
      console.log(
        `Test itinerari utente: http://localhost:${PORT}/itineraries/user/INSERISCI_USER_ID`
      );
    });
  })
  .catch((error) => {
    console.error("Errore connessione Neo4j:", error);
    process.exit(1);
  });