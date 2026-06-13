const express = require('express');
const axios = require('axios');

const router = express.Router();

const GOOGLE_PLACES_BASE_URL = 'https://places.googleapis.com/v1/places';

function toRadians(degrees) {
  return degrees * Math.PI / 180;
}

function calculateDistanceKm(lat1, lon1, lat2, lon2) {
  const earthRadiusKm = 6371;

  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);

  const rLat1 = toRadians(lat1);
  const rLat2 = toRadians(lat2);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLon / 2) *
      Math.sin(dLon / 2) *
      Math.cos(rLat1) *
      Math.cos(rLat2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return earthRadiusKm * c;
}

function normalizeGooglePlace(place) {
  const displayName = place.displayName?.text || 'Luogo senza nome';
  const location = place.location || {};

  const firstPhoto =
    Array.isArray(place.photos) && place.photos.length > 0
      ? place.photos[0]
      : null;

  const reviews = Array.isArray(place.reviews)
    ? place.reviews.map((review) => ({
        autore:
          review.authorAttribution?.displayName ||
          'Utente Google',
        fotoAutore:
          review.authorAttribution?.photoUri ||
          null,
        rating: Number(review.rating || 0),
        testo:
          review.text?.text ||
          review.originalText?.text ||
          '',
        tempoRelativo:
          review.relativePublishTimeDescription ||
          '',
      }))
    : [];

  return {
    id: place.id,
    googlePlaceId: place.id,

    nome: displayName,

    latitudine: Number(location.latitude || 0),
    longitudine: Number(location.longitude || 0),

    rating: Number(place.rating || 0),
    numeroRecensioni: Number(place.userRatingCount || 0),

    descrizione: '',
    immagineUrl: '',

    categoria:
      place.primaryTypeDisplayName?.text ||
      place.primaryType ||
      'Attrazione',

    indirizzo:
      place.formattedAddress ||
      place.shortFormattedAddress ||
      '',

    photoName: firstPhoto?.name || null,
    photoReference: null,

    source: 'google_places',

    recensioniGoogle: reviews,
  };
}

function addDistanceAndFilter(places, centerLat, centerLng, radiusKm) {
  return places
    .map(normalizeGooglePlace)
    .map((place) => {
      const distanzaKm = calculateDistanceKm(
        centerLat,
        centerLng,
        place.latitudine,
        place.longitudine,
      );

      return {
        ...place,
        distanzaKm: Number(distanzaKm.toFixed(2)),
      };
    })
    .filter((place) => place.distanzaKm <= radiusKm)
    .sort((a, b) => a.distanzaKm - b.distanzaKm);
}

router.get('/nearby', async (req, res) => {
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  const radiusKm = Number(req.query.radiusKm || 3);

  if (!lat || !lng) {
    return res.status(400).json({
      message: 'Parametri lat e lng obbligatori',
    });

  }

  if (!radiusKm || radiusKm <= 0) {
    return res.status(400).json({
      message: 'Parametro radiusKm non valido',
    });
  }

  try {
    /*
      Per rendere evidente il filtro raggio nel prototipo:
      - chiediamo sempre 10 km a Google;
      - poi applichiamo noi il filtro esatto scelto dall'utente.
    */
    const googleSearchRadiusMeters = 20000;

    const response = await axios.post(
      `${GOOGLE_PLACES_BASE_URL}:searchNearby`,
      {
        includedTypes: [
          'tourist_attraction',
          'museum',
          'church',
          'park',
          'art_gallery',
          'historical_landmark',
        ],
        maxResultCount: 20,
        rankPreference: 'POPULARITY',
        locationRestriction: {
          circle: {
            center: {
              latitude: lat,
              longitude: lng,
            },
            radius: googleSearchRadiusMeters,
          },
        },
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': process.env.GOOGLE_MAPS_API_KEY,
          'X-Goog-FieldMask': [
            'places.id',
            'places.displayName',
            'places.location',
            'places.rating',
            'places.userRatingCount',
            'places.formattedAddress',
            'places.shortFormattedAddress',
            'places.primaryType',
            'places.primaryTypeDisplayName',
            'places.photos',
          ].join(','),
        },
      },
    );

    const googlePlaces = response.data?.places || [];

    const filteredPlaces = addDistanceAndFilter(
      googlePlaces,
      lat,
      lng,
      radiusKm,
    );

    console.log(
      `Google Places Nearby - richiesti ${radiusKm} km, ricevuti ${googlePlaces.length}, filtrati ${filteredPlaces.length}`,
    );

    return res.json(filteredPlaces);
  } catch (error) {
    console.error(
      'Errore Google Places Nearby:',
      error.response?.data || error.message,
    );

    return res.status(500).json({
      message: 'Errore nella ricerca Google Places Nearby',
      error: error.response?.data || error.message,
    });
  }
});

router.get('/text-search', async (req, res) => {
  const query = req.query.q;

  if (!query) {
    return res.status(400).json({
      message: 'Parametro q mancante',
    });
  }

  try {
    const response = await axios.post(
      `${GOOGLE_PLACES_BASE_URL}:searchText`,
      {
        textQuery: query,
        maxResultCount: 10,
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': process.env.GOOGLE_MAPS_API_KEY,
          'X-Goog-FieldMask': [
            'places.id',
            'places.displayName',
            'places.location',
            'places.rating',
            'places.userRatingCount',
            'places.formattedAddress',
            'places.shortFormattedAddress',
            'places.primaryType',
            'places.primaryTypeDisplayName',
            'places.photos',
          ].join(','),
        },
      },
    );

    const places = response.data?.places || [];

    return res.json(places.map(normalizeGooglePlace));
  } catch (error) {
    console.error(
      'Errore Google Places Text Search:',
      error.response?.data || error.message,
    );

    return res.status(500).json({
      message: 'Errore nella ricerca Google Places Text Search',
      error: error.response?.data || error.message,
    });
  }
});

router.get('/detail/:placeId', async (req, res) => {
  const { placeId } = req.params;

  try {
    const response = await axios.get(
      `${GOOGLE_PLACES_BASE_URL}/${placeId}`,
      {
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': process.env.GOOGLE_MAPS_API_KEY,
          'X-Goog-FieldMask': [
            'id',
            'displayName',
            'location',
            'rating',
            'userRatingCount',
            'formattedAddress',
            'shortFormattedAddress',
            'primaryType',
            'primaryTypeDisplayName',
            'photos',
            'reviews',
          ].join(','),
        },
      },
    );

    const place = normalizeGooglePlace(response.data);

    return res.json(place);
  } catch (error) {
    console.error(
      'Errore dettaglio Google Places:',
      error.response?.data || error.message,
    );

    return res.status(500).json({
      message: 'Errore nel dettaglio Google Places',
      error: error.response?.data || error.message,
    });
  }
});

router.get('/photo', async (req, res) => {
  const photoName = req.query.name;
  const maxWidthPx = Number(req.query.maxWidthPx || 900);

  if (!photoName) {
    return res.status(400).json({
      message: 'Parametro name mancante',
    });
  }

  try {
    const response = await axios.get(
      `https://places.googleapis.com/v1/${photoName}/media`,
      {
        headers: {
          'X-Goog-Api-Key': process.env.GOOGLE_MAPS_API_KEY,
        },
        params: {
          maxWidthPx,
          skipHttpRedirect: true,
        },
      },
    );

    return res.json({
      imageUrl: response.data?.photoUri || null,
    });
  } catch (error) {
    console.error(
      'Errore foto Google Places:',
      error.response?.data || error.message,
    );

    return res.status(500).json({
      message: 'Errore nel recupero foto Google Places',
      error: error.response?.data || error.message,
    });
  }
});

module.exports = router;