import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/itinerary_stop.dart';
import '../models/place.dart';
import '../models/user.dart';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';


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
    static const String baseUrl = 'http://192.168.1.13:3000';
  //static const String baseUrl = 'http://localhost:3000';
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
  Future<List<dynamic>> getMyItineraries(String userId) async {
    final cleanUserId = Uri.encodeComponent(userId);

    final url = Uri.parse('$baseUrl/itineraries/user/$cleanUserId');

    print('GET miei itinerari: $url');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 12));

    print('Status miei itinerari: ${response.statusCode}');
    print('Body miei itinerari: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        final itineraries = data['itineraries'];

        if (itineraries is List) {
          return itineraries;
        }

        return [];
      }

      if (data is List) {
        return data;
      }

      return [];
    }

    throw Exception(
      'Errore server: ${response.statusCode} - ${response.body}',
    );
  }
  Future<Map<String, dynamic>> getTravelDiaryForStop({
    required String userId,
    required String stopId,
  }) async {
    final url = Uri.parse(
      '$baseUrl/travel-diary/stop/${Uri.encodeComponent(stopId)}/user/${Uri.encodeComponent(userId)}',
    );

    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Errore caricamento diario: ${response.statusCode} - ${response.body}');
  }

  static String resolveImageUrl(String url) {
    if (url.startsWith('https://upload.wikimedia.org/')) {
      final encoded = Uri.encodeComponent(url);
      return '$baseUrl/wiki/image-proxy?url=$encoded';
    }
    return url;
  }

  Future<String> uploadDiaryPhoto(File imageFile) async {
    final url = Uri.parse('$baseUrl/travel-diary/upload-photo');

    // Deduci il MIME type dall'estensione
    final ext = imageFile.path.toLowerCase();
    MediaType contentType;
    if (ext.endsWith('.png')) {
      contentType = MediaType('image', 'png');
    } else if (ext.endsWith('.webp')) {
      contentType = MediaType('image', 'webp');
    } else {
      contentType = MediaType('image', 'jpeg');
    }

    final request = http.MultipartRequest('POST', url);
    request.files.add(
      await http.MultipartFile.fromPath(
        'photo',
        imageFile.path,
        contentType: contentType,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['url'].toString();
    }

    throw Exception('Errore upload foto: ${response.statusCode} - ${response.body}');
  }

  Future<Map<String, dynamic>> saveTravelDiaryForStop({
      required String userId,
      required String stopId,
      required String placeId,
      required String placeName,
      required int rating,
      required String note,
      List<String> photos = const [],
    }) async {
      final url = Uri.parse('$baseUrl/travel-diary/save');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'stopId': stopId,
          'placeId': placeId,
          'placeName': placeName,
          'rating': rating,
          'note': note,
          'photos': photos,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw Exception('Errore salvataggio diario: ${response.statusCode} - ${response.body}');
    }

  Future<Map<String, dynamic>> createTravelReport({
    required String userId,
    required String stopId,
    required String placeId,
    required String placeName,
    required String categoria,
    required String descrizione,
  }) async {
    final url = Uri.parse('$baseUrl/travel-diary/report');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'stopId': stopId,
        'placeId': placeId,
        'placeName': placeName,
        'categoria': categoria,
        'descrizione': descrizione,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Errore invio segnalazione: ${response.statusCode} - ${response.body}');
  }

  Future<void> deleteTravelReport({
    required String userId,
    required String reportId,
  }) async {
    final url = Uri.parse(
      '$baseUrl/travel-diary/report/${Uri.encodeComponent(reportId)}/user/${Uri.encodeComponent(userId)}',
    );

    final response = await http.delete(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    throw Exception('Errore eliminazione segnalazione: ${response.statusCode} - ${response.body}');
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

  // ============================================================
  //  METODI DI AUTENTICAZIONE
  // ============================================================

  /// Login unico email/password.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return AuthResult.fromJson(decoded);
    } else {
      throw Exception(decoded['message']?.toString() ?? 'Errore login');
    }
  }

  /// Registrazione turista.
  Future<AuthResult> registerTourist({
    required String nome,
    required String email,
    required String password,
    required bool accettaCondizioni,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register/tourist');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nome': nome,
        'email': email,
        'password': password,
        'accettaCondizioni': accettaCondizioni,
      }),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201) {
      return AuthResult.fromJson(decoded);
    } else {
      throw Exception(decoded['message']?.toString() ?? 'Errore registrazione');
    }
  }

  /// Registrazione operatore comunale.
  Future<AuthResult> registerMunicipality({
    required String nome,
    required String email,
    required String password,
    required String nomeComune,
    required String codiceAttivazione,
    required String ruoloReferente,
    required String metodoPagamento,
    required bool accettaCondizioni,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register/municipality');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nome': nome,
        'email': email,
        'password': password,
        'nomeComune': nomeComune,
        'codiceAttivazione': codiceAttivazione,
        'ruoloReferente': ruoloReferente,
        'metodoPagamento': metodoPagamento,
        'accettaCondizioni': accettaCondizioni,
      }),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201) {
      return AuthResult.fromJson(decoded);
    } else {
      throw Exception(decoded['message']?.toString() ?? 'Errore registrazione');
    }
  }

  // ============================================================
  //  METODI DASHBOARD COMUNALE
  //  Tutte richiedono il token JWT dell'operatore.
  // ============================================================

  Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// Card riepilogo in alto (itinerari, luoghi, hidden gems, segnalazioni).
  Future<Map<String, dynamic>> getDashboardSummary(String token) async {
    final url = Uri.parse('$baseUrl/dashboard/summary');
    final response = await http.get(url, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Errore nel caricamento del riepilogo');
    }
  }

  /// Luoghi più presenti negli itinerari (RF-C3).
  Future<List<Map<String, dynamic>>> getTopPlaces(String token) async {
    final url = Uri.parse('$baseUrl/dashboard/top-places');
    final response = await http.get(url, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Errore nel caricamento dei luoghi più presenti');
    }
  }

  /// Luoghi da valorizzare (RF-C4).
  Future<List<Map<String, dynamic>>> getPlacesToImprove(String token) async {
    final url = Uri.parse('$baseUrl/dashboard/places-to-improve');
    final response = await http.get(url, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Errore nel caricamento dei luoghi da valorizzare');
    }
  }

  /// Filtri più usati negli itinerari (RF-C5).
  Future<List<Map<String, dynamic>>> getDashboardFilters(String token) async {
    final url = Uri.parse('$baseUrl/dashboard/filters');
    final response = await http.get(url, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Errore nel caricamento dei filtri');
    }
  }

  /// Segnalazioni ricevute (RF-C6). Per ora torna lista vuota.
  Future<List<Map<String, dynamic>>> getDashboardReports(String token) async {
    final url = Uri.parse('$baseUrl/dashboard/reports');

    print('GET dashboard reports: $url');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('Status dashboard reports: ${response.statusCode}');
    print('Body dashboard reports: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      if (data is Map<String, dynamic> && data['reports'] is List) {
        return (data['reports'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      return [];
    }

    throw Exception(
      'Errore dashboard reports: ${response.statusCode} - ${response.body}',
    );
  }

}