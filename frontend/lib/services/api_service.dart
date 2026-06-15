import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/itinerary_stop.dart';
import '../models/place.dart';

class ApiService {
  /*
    Chrome/Web:
    usa http://localhost:3000

    Emulatore Android:
    usa http://10.0.2.2:3000

    Telefono Android reale:
    usa l'IP del PC nella stessa rete Wi-Fi, ad esempio:
   'http://10.195.229.82:3000'
  */
  static const String baseUrl = 'http://172.20.10.4:3000';
  Future<Map<String, dynamic>> searchMunicipalityByName(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);

    final url = Uri.parse('$baseUrl/municipality/search?q=$encodedQuery');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Errore nella ricerca del Comune: ${response.body}',
      );
    }
  }
  Future<Map<String, dynamic>> checkMunicipalityByPoint({
    required double latitudine,
    required double longitudine,
  }) async {
    final url = Uri.parse(
      '$baseUrl/municipality/check-point?lat=$latitudine&lng=$longitudine',
    );

    final response = await http.get(url);

    final decodedBody = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return decodedBody as Map<String, dynamic>;
    }

    final message = decodedBody is Map<String, dynamic>
        ? decodedBody['message']?.toString() ?? response.body
        : response.body;

    throw Exception(message);
  }
  Future<Map<String, dynamic>> checkMunicipalityStatus(
      String municipalityId,
      ) async {
    final url = Uri.parse('$baseUrl/municipality/$municipalityId/status');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Errore nella verifica del Comune');
    }
  }
  Future<Map<String, dynamic>> getGooglePlaceDetailRaw(String placeId) async {
    final url = Uri.parse('$baseUrl/google/places/detail/$placeId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Errore nel caricamento dettaglio Google Places: ${response.body}',
      );
    }
  }
  Future<List<String>> getWikipediaImages(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);

    final url = Uri.parse('$baseUrl/wiki/images?q=$encodedQuery');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

      return data.map((item) => item.toString()).toList();
    } else {
      return [];
    }
  }
  Future<Map<String, dynamic>> getWikipediaSummary(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);

    final url = Uri.parse('$baseUrl/wiki/summary?q=$encodedQuery');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Errore nel caricamento descrizione Wikipedia: ${response.body}',
      );
    }
  }

  Future<List<Place>> getPlacesByMunicipality(
      String municipalityId,
      ) async {
    final url = Uri.parse('$baseUrl/places/$municipalityId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

      return data
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Errore nel caricamento dei luoghi');
    }
  }

  Future<List<Place>> getPlacesByMunicipalityAndRadius(
      String municipalityId,
      int radiusKm,
      ) async {
    final url = Uri.parse('$baseUrl/places/$municipalityId/radius/$radiusKm');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

      return data
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Errore nel caricamento dei luoghi per raggio');
    }
  }

  Future<List<Place>> getFilteredPlaces(
      String municipalityId,
      String filterType,
      ) async {
    final url = Uri.parse('$baseUrl/places/$municipalityId/filter/$filterType');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

      return data
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Errore nel caricamento dei luoghi filtrati');
    }
  }

  Future<List<Place>> getFilteredPlacesByRadius(
      String municipalityId,
      int radiusKm,
      String filterType,
      ) async {
    final url = Uri.parse(
      '$baseUrl/places/$municipalityId/radius/$radiusKm/filter/$filterType',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

      return data
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Errore nel caricamento dei luoghi filtrati per raggio');
    }
  }

  Future<Place> getPlaceDetail(String placeId) async {
    final url = Uri.parse('$baseUrl/places/detail/$placeId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      return Place.fromJson(data);
    } else {
      throw Exception('Errore nel caricamento del dettaglio luogo');
    }
  }

  Future<List<Place>> searchPlacesFree(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);

    final url = Uri.parse('$baseUrl/places/search/free?q=$encodedQuery');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

      return data
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Errore nella ricerca libera delle tappe');
    }
  }

  Future<List<Place>> getGooglePlacesNearby({
    required double latitudine,
    required double longitudine,
    required int radiusKm,
  }) async {
    final url = Uri.parse(
      '$baseUrl/google/places/nearby?lat=$latitudine&lng=$longitudine&radiusKm=$radiusKm',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

      return data
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
        'Errore nel caricamento dei luoghi Google Places: ${response.body}',
      );
    }
  }

  Future<List<Place>> searchGooglePlacesText(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);

    final url = Uri.parse(
      '$baseUrl/google/places/text-search?q=$encodedQuery',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

      return data
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
        'Errore nella ricerca Google Places: ${response.body}',
      );
    }
  }

  Future<Place> getGooglePlaceDetail(String placeId) async {
    final url = Uri.parse('$baseUrl/google/places/detail/$placeId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      return Place.fromJson(data);
    } else {
      throw Exception(
        'Errore nel caricamento del dettaglio Google Places: ${response.body}',
      );
    }
  }

  Future<String?> getGooglePlacePhotoUrl(String photoName) async {
    final encodedPhotoName = Uri.encodeQueryComponent(photoName);

    final url = Uri.parse(
      '$baseUrl/google/places/photo?name=$encodedPhotoName&maxWidthPx=800',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      return data['imageUrl']?.toString();
    } else {
      return null;
    }
  }

  Future<Map<String, dynamic>> generateItinerary({
    required List<String> placeIds,
    required String filterType,
    int numeroGiorni = 1,
  }) async {
    final url = Uri.parse('$baseUrl/itineraries/generate');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'placeIds': placeIds,
        'filterType': filterType,
        'numeroGiorni': numeroGiorni,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      final List<dynamic> stopsJson = data['stops'] ?? [];

      final stops = stopsJson
          .map((item) => ItineraryStop.fromJson(item as Map<String, dynamic>))
          .toList();

      return {
        'filterType': data['filterType'],
        'numeroGiorni': data['numeroGiorni'],
        'durataStimataMinuti': data['durataStimataMinuti'],
        'criterioOrdinamento': data['criterioOrdinamento'],
        'stops': stops,
      };
    } else {
      throw Exception(
        'Errore nella generazione dell’itinerario: ${response.body}',
      );
    }
  }

  Future<String> saveItinerary({
    required String userId,
    required String municipalityId,
    required String titolo,
    required String filterType,
    required int numeroGiorni,
    required List<ItineraryStop> stops,
  }) async {
    final url = Uri.parse('$baseUrl/itineraries/save');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'userId': userId,
        'municipalityId': municipalityId,
        'titolo': titolo,
        'filterType': filterType,
        'numeroGiorni': numeroGiorni,
        'stops': stops.map((stop) => stop.toJson()).toList(),
      }),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      return data['itineraryId'].toString();
    } else {
      throw Exception(
        'Errore nel salvataggio dell’itinerario: ${response.body}',
      );
    }
  }
}