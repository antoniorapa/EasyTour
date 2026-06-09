const express = require("express");
const cors = require("cors");
const placesRoutes = require("./routes/places");
const municipalityRoutes = require("./routes/municipality");
const itinerariesRoutes = require("./routes/itineraries");
require("dotenv").config();

const { verifyConnection } = require("./db");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.json({
    message: "EasyTour backend attivo"
  });
});
app.use("/places", placesRoutes);
app.use("/municipality", municipalityRoutes);
app.use("/itineraries", itinerariesRoutes);


app.get("/test-neo4j", async (req, res) => {
  const { driver } = require("./db");
  const session = driver.session();

  try {
    const result = await session.run(
      'RETURN "Connessione Neo4j funzionante" AS messaggio'
    );

    res.json({
      success: true,
      message: result.records[0].get("messaggio")
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  } finally {
    await session.close();
  }
});

const PORT = process.env.PORT || 3000;

verifyConnection().then(() => {
  app.listen(PORT, () => {
    console.log(`Server avviato su porta ${PORT}`);
  });
});