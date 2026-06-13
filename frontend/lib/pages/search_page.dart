import 'dart:math';

import '../widgets/easytour_header.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/itinerary_stop.dart';
import '../models/place.dart';
import '../services/api_service.dart';
import 'generated_itinerary_page.dart';
import 'place_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ApiService apiService = ApiService();
  final TextEditingController cityController = TextEditingController();

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color softBlue = Color(0xFFEAF4FA);
  static const Color softOrange = Color(0xFFFFF2DF);

  final List<int> radiusOptions = [1, 3, 5, 10, 20];
  final List<int> dayOptions = [1, 2, 3];
  final List<int> availableHourOptions = [2, 4, 6, 8];

  final Map<String, Future<String?>> _previewImageCache = {};

  GoogleMapController? mapController;

  String? selectedMunicipalityId;
  String? selectedMunicipalityName;

  double? selectedLatitude;
  double? selectedLongitude;

  int selectedRadius = 3;
  String selectedFilter = 'none';

  String searchCenterLabel = 'Nessun Comune selezionato';
  String searchMode = 'Comune non selezionato';

  bool municipalitySelected = false;
  bool municipalityActive = false;
  bool usingRealLocation = false;
  bool isSelectingPoint = false;
  bool isLoadingLocation = false;
  bool isLoading = false;
  bool isGeneratingItinerary = false;

  String? errorMessage;
  String? locationMessage;

  List<Place> allGooglePlaces = [];
  List<Place> places = [];

  @override
  void initState() {
    super.initState();
    locationMessage =
    'Scegli se usare la tua posizione, selezionare un punto sulla mappa oppure cercare un Comune.';
  }

  @override
  void dispose() {
    cityController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  bool get canUseApp {
    return municipalitySelected &&
        municipalityActive &&
        selectedLatitude != null &&
        selectedLongitude != null;
  }

  bool get canShowMap {
    return canUseApp ||
        isSelectingPoint ||
        (selectedLatitude != null && selectedLongitude != null);
  }

  Future<void> _showComuneNonPresentePopup() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Comune non presente nell’app',
            style: TextStyle(
              color: darkBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Il Comune selezionato non è presente nell’app. Non puoi accedere alle funzionalità di EasyTour.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Ho capito'),
            ),
          ],
        );
      },
    );
  }

  Future<void> searchMunicipality() async {
    final query = cityController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci il nome di un Comune.'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      places = [];
      allGooglePlaces = [];
      municipalitySelected = false;
      municipalityActive = false;
      usingRealLocation = false;
      isSelectingPoint = false;
      selectedMunicipalityId = null;
      selectedMunicipalityName = null;
      selectedLatitude = null;
      selectedLongitude = null;
      searchCenterLabel = 'Verifica Comune...';
      searchMode = 'Verifica iscrizione';
      locationMessage = 'Verifico se il Comune è attivo su EasyTour...';
    });

    try {
      final municipality = await apiService.searchMunicipalityByName(query);

      final bool found = municipality['found'] == true;
      final bool active = municipality['active'] == true;

      if (!found || !active) {
        if (!mounted) return;

        setState(() {
          municipalitySelected = found;
          municipalityActive = false;
          selectedMunicipalityId = municipality['id']?.toString();
          selectedMunicipalityName = municipality['nome']?.toString();
          cityController.text = municipality['nome']?.toString() ?? query;

          places = [];
          allGooglePlaces = [];

          searchCenterLabel = 'Comune non disponibile';
          searchMode = 'Comune non presente nell’app';

          errorMessage = 'Comune non presente nell’app.';
          locationMessage =
          'Comune non presente nell’app: mappa, attrazioni e itinerari sono bloccati.';
        });

        await _showComuneNonPresentePopup();
        return;
      }

      final lat = _toDouble(municipality['latitudine']);
      final lng = _toDouble(municipality['longitudine']);
      final municipalityName = municipality['nome']?.toString() ?? query;

      if (!mounted) return;

      setState(() {
        municipalitySelected = true;
        municipalityActive = true;
        selectedMunicipalityId = municipality['id']?.toString();
        selectedMunicipalityName = municipalityName;
        selectedLatitude = lat;
        selectedLongitude = lng;
        usingRealLocation = false;
        isSelectingPoint = false;
        selectedFilter = 'none';
        searchCenterLabel = municipalityName;
        searchMode = 'Centro Comune';
        cityController.text = municipalityName;
        locationMessage =
        'Comune attivo. Ricerca basata sul centro di $municipalityName.';
      });

      await refreshPlaces();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Errore durante la verifica del Comune: $e';
        locationMessage = 'Impossibile verificare il Comune.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> useCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
      isLoading = true;
      isSelectingPoint = false;
      errorMessage = null;
      places = [];
      allGooglePlaces = [];
      selectedFilter = 'none';
      locationMessage = 'Recupero posizione attuale...';
      searchMode = 'Verifica posizione attuale';
      searchCenterLabel = 'La tua posizione';
    });

    try {
      final position = await _determinePosition();

      if (!mounted) return;

      setState(() {
        selectedLatitude = position.latitude;
        selectedLongitude = position.longitude;
        usingRealLocation = true;
        locationMessage = 'Controllo il Comune della tua posizione attuale...';
      });

      final municipalityCheck = await apiService.checkMunicipalityByPoint(
        latitudine: position.latitude,
        longitudine: position.longitude,
      );

      final bool found = municipalityCheck['found'] == true;
      final bool active = municipalityCheck['active'] == true;

      if (!found || !active) {
        if (!mounted) return;

        setState(() {
          municipalitySelected = found;
          municipalityActive = false;

          selectedMunicipalityId = municipalityCheck['id']?.toString();
          selectedMunicipalityName = municipalityCheck['nome']?.toString();

          places = [];
          allGooglePlaces = [];

          usingRealLocation = false;
          isSelectingPoint = false;

          searchCenterLabel = 'Comune non disponibile';
          searchMode = 'Posizione attuale non valida';

          errorMessage = 'Comune non presente nell’app.';
          locationMessage =
          'Comune non presente nell’app: non puoi accedere alle funzionalità.';
        });

        await _showComuneNonPresentePopup();
        return;
      }

      final newMunicipalityId = municipalityCheck['id']?.toString();
      final newMunicipalityName =
          municipalityCheck['nome']?.toString() ?? 'Comune attivo';

      if (!mounted) return;

      setState(() {
        selectedMunicipalityId = newMunicipalityId;
        selectedMunicipalityName = newMunicipalityName;

        municipalitySelected = true;
        municipalityActive = true;

        selectedLatitude = position.latitude;
        selectedLongitude = position.longitude;

        usingRealLocation = true;
        isSelectingPoint = false;

        searchMode = 'Posizione attuale';
        searchCenterLabel = 'La tua posizione';

        selectedFilter = 'none';
        cityController.text = newMunicipalityName;

        locationMessage =
        'Ricerca basata sulla tua posizione attuale nel Comune attivo: $newMunicipalityName.';
      });

      await refreshPlaces();
      await _animateMapToCurrentArea();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        locationMessage = 'Impossibile verificare la posizione attuale.';
        errorMessage = 'Errore posizione: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingLocation = false;
        });
      }
    }
  }

  void startInitialPointSelection() {
    setState(() {
      selectedLatitude ??= 41.9028;
      selectedLongitude ??= 12.4964;

      isSelectingPoint = true;
      usingRealLocation = false;
      municipalitySelected = false;
      municipalityActive = false;
      selectedMunicipalityId = null;
      selectedMunicipalityName = null;
      places = [];
      allGooglePlaces = [];
      errorMessage = null;

      searchCenterLabel = 'Seleziona un punto';
      searchMode = 'Scelta sulla mappa';
      locationMessage =
      'Muovi la mappa e tocca un punto. Controlleremo se appartiene a un Comune presente nell’app.';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateMapToCurrentArea();
    });
  }

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Servizi di localizzazione disattivati.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw Exception('Permesso posizione negato.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permesso posizione negato permanentemente.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );
  }

  Future<void> refreshPlaces() async {
    if (!canUseApp) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
      places = [];
      allGooglePlaces = [];
    });

    try {
      final result = await apiService.getGooglePlacesNearby(
        latitudine: selectedLatitude!,
        longitudine: selectedLongitude!,
        radiusKm: selectedRadius,
      );

      final placesWithDistance = result.map((place) {
        final distance = place.distanzaKm ??
            _calculateDistanceKm(
              selectedLatitude!,
              selectedLongitude!,
              place.latitudine,
              place.longitudine,
            );

        return place.copyWith(
          distanzaKm: double.parse(distance.toStringAsFixed(2)),
        );
      }).toList();

      placesWithDistance.sort((a, b) {
        final distanceA = a.distanzaKm ?? 9999;
        final distanceB = b.distanzaKm ?? 9999;
        return distanceA.compareTo(distanceB);
      });

      if (!mounted) return;

      setState(() {
        allGooglePlaces = placesWithDistance;
        places = _applyFilter(placesWithDistance, selectedFilter);
      });

      await _animateMapToCurrentArea();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        places = [];
        allGooglePlaces = [];
        errorMessage = 'Errore durante la ricerca delle attrazioni: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<Place> _applyFilter(List<Place> sourcePlaces, String filterType) {
    final filtered = List<Place>.from(sourcePlaces);

    if (filterType == 'none') {
      return filtered;
    }

    if (filterType == 'two_hours') {
      filtered.sort((a, b) {
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;

        final distanceA = a.distanzaKm ?? 9999;
        final distanceB = b.distanzaKm ?? 9999;
        return distanceA.compareTo(distanceB);
      });

      return filtered.take(3).toList();
    }

    if (filterType == 'budget') {
      final budgetKeywords = [
        'park',
        'garden',
        'tourist attraction',
        'historical landmark',
        'plaza',
        'square',
        'church',
        'museum',
      ];

      return filtered.where((place) {
        final category = place.categoria.toLowerCase();

        return budgetKeywords.any(
              (keyword) => category.contains(keyword),
        );
      }).toList();
    }

    if (filterType == 'hidden') {
      filtered.sort((a, b) {
        final reviewCompare = a.numeroRecensioni.compareTo(
          b.numeroRecensioni,
        );

        if (reviewCompare != 0) return reviewCompare;

        return b.rating.compareTo(a.rating);
      });

      return filtered.take(5).toList();
    }

    return filtered;
  }

  Future<void> _onRadiusChanged(int radius) async {
    setState(() {
      selectedRadius = radius;
      selectedFilter = 'none';
    });

    await refreshPlaces();
  }

  void applyFilter(String filterType) {
    if (!canUseApp) return;

    setState(() {
      selectedFilter = filterType;
      places = _applyFilter(allGooglePlaces, filterType);
    });
  }

  void enableManualPointSelection() {
    setState(() {
      isSelectingPoint = true;
      usingRealLocation = false;
      locationMessage =
      'Muovi la mappa e tocca un punto per impostarlo come centro della ricerca.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tocca un punto sulla mappa per cercare attrazioni lì.'),
      ),
    );
  }

  Future<void> selectPointOnMap(LatLng point) async {
    if (!isSelectingPoint) return;

    final previousLatitude = selectedLatitude;
    final previousLongitude = selectedLongitude;
    final previousMunicipalityId = selectedMunicipalityId;
    final previousMunicipalityName = selectedMunicipalityName;
    final previousSearchCenterLabel = searchCenterLabel;
    final previousSearchMode = searchMode;
    final previousUsingRealLocation = usingRealLocation;
    final previousMunicipalitySelected = municipalitySelected;
    final previousMunicipalityActive = municipalityActive;
    final previousCityText = cityController.text;

    setState(() {
      selectedLatitude = point.latitude;
      selectedLongitude = point.longitude;
      usingRealLocation = false;
      searchMode = 'Verifica punto selezionato';
      searchCenterLabel = 'Punto selezionato sulla mappa';
      selectedFilter = 'none';
      locationMessage = 'Controllo il Comune del punto selezionato...';
      isLoading = true;
      errorMessage = null;
    });

    try {
      final municipalityCheck = await apiService.checkMunicipalityByPoint(
        latitudine: point.latitude,
        longitudine: point.longitude,
      );

      final bool found = municipalityCheck['found'] == true;
      final bool active = municipalityCheck['active'] == true;

      if (!found || !active) {
        if (!mounted) return;

        setState(() {
          selectedLatitude = point.latitude;
          selectedLongitude = point.longitude;

          selectedMunicipalityId = municipalityCheck['id']?.toString();
          selectedMunicipalityName = municipalityCheck['nome']?.toString();

          municipalitySelected = found;
          municipalityActive = false;

          usingRealLocation = false;
          isSelectingPoint = true;

          places = [];
          allGooglePlaces = [];

          searchCenterLabel = 'Comune non disponibile';
          searchMode = 'Punto non valido';

          errorMessage = 'Comune non presente nell’app.';
          locationMessage =
          'Comune non presente nell’app: scegli un altro punto oppure inserisci un Comune diverso.';
        });

        await _showComuneNonPresentePopup();
        return;
      }

      if (!mounted) return;

      final newMunicipalityId = municipalityCheck['id']?.toString();
      final newMunicipalityName =
          municipalityCheck['nome']?.toString() ?? 'Comune attivo';

      setState(() {
        selectedMunicipalityId = newMunicipalityId;
        selectedMunicipalityName = newMunicipalityName;

        municipalitySelected = true;
        municipalityActive = true;

        selectedLatitude = point.latitude;
        selectedLongitude = point.longitude;

        usingRealLocation = false;
        isSelectingPoint = false;

        searchMode = 'Punto selezionato';
        searchCenterLabel = 'Punto scelto';

        selectedFilter = 'none';

        cityController.text = newMunicipalityName;

        locationMessage =
        'Ricerca basata sul punto selezionato nel Comune attivo: $newMunicipalityName.';
      });

      await refreshPlaces();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        selectedLatitude = previousLatitude;
        selectedLongitude = previousLongitude;
        selectedMunicipalityId = previousMunicipalityId;
        selectedMunicipalityName = previousMunicipalityName;
        searchCenterLabel = previousSearchCenterLabel;
        searchMode = previousSearchMode;
        usingRealLocation = previousUsingRealLocation;
        municipalitySelected = previousMunicipalitySelected;
        municipalityActive = previousMunicipalityActive;
        cityController.text = previousCityText;

        isSelectingPoint = previousMunicipalityActive == true ? false : true;

        errorMessage = 'Errore durante il controllo del punto selezionato: $e';
        locationMessage = 'Impossibile verificare il Comune del punto.';
      });

      await _animateMapToCurrentArea();
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> showGenerateItineraryDialog() async {
    if (!canUseApp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prima cerca un Comune attivo.'),
        ),
      );
      return;
    }

    if (places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nessuna attrazione disponibile per generare itinerario.',
          ),
        ),
      );
      return;
    }

    int dialogDays = 1;
    int dialogHoursPerDay = 4;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('Durata itinerario'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scegli giorni e ore disponibili. L’itinerario verrà generato entro questi limiti.',
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<int>(
                    value: dialogDays,
                    decoration: _inputDecoration('Numero giorni'),
                    items: dayOptions.map((days) {
                      return DropdownMenuItem<int>(
                        value: days,
                        child: Text(
                          '$days ${days == 1 ? "giorno" : "giorni"}',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        dialogDays = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: dialogHoursPerDay,
                    decoration: _inputDecoration('Ore al giorno'),
                    items: availableHourOptions.map((hours) {
                      return DropdownMenuItem<int>(
                        value: hours,
                        child: Text('$hours ore/giorno'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        dialogHoursPerDay = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, {
                      'days': dialogDays,
                      'hoursPerDay': dialogHoursPerDay,
                    });
                  },
                  icon: const Icon(Icons.route),
                  label: const Text('Genera'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    await generateItinerary(
      numeroGiorni: result['days'] ?? 1,
      oreDisponibiliAlGiorno: result['hoursPerDay'] ?? 4,
    );
  }

  Future<void> generateItinerary({
    required int numeroGiorni,
    required int oreDisponibiliAlGiorno,
  }) async {
    setState(() {
      isGeneratingItinerary = true;
    });

    try {
      final maxMinutes = numeroGiorni * oreDisponibiliAlGiorno * 60;

      final selectedStops = <ItineraryStop>[];
      int usedMinutes = 0;
      double currentLat = selectedLatitude!;
      double currentLng = selectedLongitude!;

      for (final place in places) {
        final distanceKm = _calculateDistanceKm(
          currentLat,
          currentLng,
          place.latitudine,
          place.longitudine,
        );

        final arrivalMinutes = selectedStops.isEmpty
            ? 0
            : _estimateArrivalMinutes(distanceKm);
        final visitMinutes = _estimateVisitTimeMinutes(place);

        final additionalMinutes = arrivalMinutes + visitMinutes;

        if (selectedStops.isNotEmpty &&
            usedMinutes + additionalMinutes > maxMinutes) {
          break;
        }

        if (selectedStops.isEmpty && additionalMinutes > maxMinutes) {
          break;
        }

        selectedStops.add(
          ItineraryStop(
            ordine: selectedStops.length + 1,
            giorno: 1,
            tempoVisitaStimato: visitMinutes,
            tempoArrivoStimato: arrivalMinutes,
            tempoPausaStimato: 0,
            distanzaDalPuntoPrecedenteKm:
            double.parse(distanceKm.toStringAsFixed(2)),
            place: place.copyWith(
              distanzaKm: double.parse(distanceKm.toStringAsFixed(2)),
            ),
          ),
        );

        usedMinutes += additionalMinutes;
        currentLat = place.latitudine;
        currentLng = place.longitudine;
      }

      if (selectedStops.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nessuna attrazione rientra nel tempo disponibile.',
            ),
          ),
        );

        return;
      }

      final discardedCount = places.length - selectedStops.length;

      if (!mounted) return;

      if (discardedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Itinerario adattato: $discardedCount attrazioni escluse per rispettare il tempo.',
            ),
          ),
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GeneratedItineraryPage(
            initialStops: selectedStops,
            availablePlaces: allGooglePlaces,
            filterType: selectedFilter,
            numeroGiorni: numeroGiorni,
            durataStimataMinuti: usedMinutes,
            minutiDisponibiliAlGiorno: oreDisponibiliAlGiorno * 60,
            municipalityId: selectedMunicipalityId!,
            municipalityName: selectedMunicipalityName ?? 'Comune selezionato',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nella generazione dell’itinerario: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingItinerary = false;
        });
      }
    }
  }

  int _estimateVisitTimeMinutes(Place place) {
    final category = place.categoria.toLowerCase();

    if (category.contains('museum')) return 60;
    if (category.contains('castle')) return 60;
    if (category.contains('church')) return 45;
    if (category.contains('historical')) return 45;
    if (category.contains('landmark')) return 45;
    if (category.contains('park')) return 40;
    if (category.contains('garden')) return 40;
    if (category.contains('tourist attraction')) return 40;

    return 40;
  }

  int _estimateArrivalMinutes(double distanceKm) {
    if (distanceKm <= 0) return 0;
    return max(5, (distanceKm * 12).round());
  }

  double _calculateDistanceKm(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const earthRadiusKm = 6371;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final rLat1 = _toRadians(lat1);
    final rLat2 = _toRadians(lat2);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(rLat1) * cos(rLat2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<String?> _getPreviewImageForPlace(Place place) {
    final cacheKey = place.id;

    if (_previewImageCache.containsKey(cacheKey)) {
      return _previewImageCache[cacheKey]!;
    }

    final future = _fetchPreviewImage(place);
    _previewImageCache[cacheKey] = future;
    return future;
  }

  Future<String?> _fetchPreviewImage(Place place) async {
    final loadedImages = <String>[];

    if (place.immagineUrl != null && place.immagineUrl!.isNotEmpty) {
      loadedImages.add(place.immagineUrl!);
    }

    final photoToken = place.photoReference ?? place.photoName;

    if (photoToken != null && photoToken.isNotEmpty) {
      try {
        final googlePhotoUrl = await apiService.getGooglePlacePhotoUrl(
          photoToken,
        );

        if (googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
          loadedImages.add(googlePhotoUrl);
        }
      } catch (_) {}
    }

    try {
      final wikiSummary = await apiService.getWikipediaSummary(place.nome);
      final wikiImageUrl = wikiSummary['immagineUrl']?.toString();

      if (wikiImageUrl != null && wikiImageUrl.isNotEmpty) {
        loadedImages.add(wikiImageUrl);
      }
    } catch (_) {}

    try {
      final wikiImages = await apiService.getWikipediaImages(place.nome);

      for (final imageUrl in wikiImages) {
        if (imageUrl.isNotEmpty) {
          loadedImages.add(imageUrl);
        }
      }
    } catch (_) {}

    final uniqueImages = loadedImages.toSet().toList();

    if (uniqueImages.isEmpty) {
      return null;
    }

    return uniqueImages.first;
  }

  Set<Marker> _buildMarkers() {
    if (selectedLatitude == null || selectedLongitude == null) return {};

    final markers = <Marker>{};

    markers.add(
      Marker(
        markerId: const MarkerId('search_center'),
        position: LatLng(selectedLatitude!, selectedLongitude!),
        infoWindow: InfoWindow(
          title: searchCenterLabel,
          snippet: searchMode,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
      ),
    );

    if (!canUseApp) return markers;

    for (final place in places) {
      markers.add(
        Marker(
          markerId: MarkerId(place.id),
          position: LatLng(place.latitudine, place.longitudine),
          infoWindow: InfoWindow(
            title: place.nome,
            snippet: place.distanzaKm == null
                ? place.categoria
                : '${place.categoria} • ${place.distanzaKm!.toStringAsFixed(2)} km',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaceDetailPage(placeId: place.id),
                ),
              );
            },
          ),
        ),
      );
    }

    return markers;
  }

  Set<Circle> _buildCircles() {
    if (!canUseApp) return {};

    return {
      Circle(
        circleId: const CircleId('search_radius'),
        center: LatLng(selectedLatitude!, selectedLongitude!),
        radius: selectedRadius * 1000,
        fillColor: const Color(0x33005A8D),
        strokeColor: primaryBlue,
        strokeWidth: 2,
      ),
    };
  }

  double _zoomForRadius() {
    if (selectedRadius <= 1) return 15;
    if (selectedRadius <= 3) return 14;
    if (selectedRadius <= 5) return 13;
    if (selectedRadius <= 10) return 12;
    return 11;
  }

  Future<void> _animateMapToCurrentArea() async {
    final controller = mapController;

    if (controller == null ||
        selectedLatitude == null ||
        selectedLongitude == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(selectedLatitude!, selectedLongitude!),
          zoom: canUseApp ? _zoomForRadius() : 6,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Colors.black54),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
    );
  }

  InputDecoration _compactInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      labelStyle: const TextStyle(
        color: Colors.black54,
        fontSize: 12,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: Stack(
        children: [
          Column(
            children: [
              EasyTourHeader(
                rightIcon: canUseApp
                    ? Icons.verified_rounded
                    : Icons.lock_outline_rounded,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: primaryBlue,
                  onRefresh: () async {
                    if (canUseApp) {
                      await refreshPlaces();
                    }
                  },
                  child: ListView(
                    padding: EdgeInsets.zero,
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _buildSearchCard(),
                      if (canUseApp) _buildFilterSection(),
                      if (canShowMap) _buildMapCard(),
                      if (canUseApp) _buildPlacesHeader(),
                      if (canUseApp) _buildPlacesList(),
                      if (!canUseApp && !isSelectingPoint)
                        _buildBlockedState(),
                      if (!canUseApp && isSelectingPoint)
                        _buildMapSelectionHint(),
                      const SizedBox(height: 110),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (canUseApp) _buildFloatingItineraryButton(),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dove vuoi andare?',
            style: TextStyle(
              color: darkBlue,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            locationMessage ??
                'Scegli se usare la tua posizione, selezionare un punto sulla mappa oppure cercare un Comune.',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (!canUseApp) ...[
            TextField(
              controller: cityController,
              decoration: _inputDecoration('Cerca Comune').copyWith(
                hintText: 'Es. Fisciano, Roma, Salerno...',
                prefixIcon: const Icon(Icons.location_city, color: primaryBlue),
                suffixIcon: IconButton(
                  icon: isLoading && !canUseApp
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.search, color: orange),
                  onPressed: isLoading ? null : searchMunicipality,
                ),
              ),
              onSubmitted: (_) => searchMunicipality(),
            ),
            const SizedBox(height: 14),
            _buildInitialActions(),
          ],
          if (canUseApp) ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: DropdownButtonFormField<int>(
                      value: selectedRadius,
                      isExpanded: true,
                      decoration: _compactInputDecoration('Raggio'),
                      items: radiusOptions.map((radius) {
                        return DropdownMenuItem<int>(
                          value: radius,
                          child: Text(
                            '$radius km',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: isLoading || isLoadingLocation
                          ? null
                          : (value) {
                        if (value == null) return;
                        _onRadiusChanged(value);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: TextField(
                      controller: cityController,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: _compactInputDecoration('Comune').copyWith(
                        hintText: 'Comune',
                        prefixIcon: const Icon(
                          Icons.location_city,
                          color: primaryBlue,
                          size: 19,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        suffixIcon: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          icon: isLoading
                              ? const SizedBox(
                            height: 17,
                            width: 17,
                            child:
                            CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(
                            Icons.search,
                            color: orange,
                            size: 20,
                          ),
                          onPressed: isLoading ? null : searchMunicipality,
                        ),
                      ),
                      onSubmitted: (_) => searchMunicipality(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildModeButtons(),
            const SizedBox(height: 12),
            _buildCurrentSearchInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildInitialActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed:
            isLoadingLocation || isLoading ? null : useCurrentLocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: isLoadingLocation
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.my_location_rounded),
            label: Text(
              isLoadingLocation
                  ? 'Rilevo posizione...'
                  : 'Usa la mia posizione attuale',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed:
            isLoading || isLoadingLocation ? null : startInitialPointSelection,
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryBlue,
              side: const BorderSide(color: primaryBlue, width: 1.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text(
              'Scegli un punto sulla mappa',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeButtons() {
    return Row(
      children: [
        Expanded(
          child: _modeButton(
            label: isLoadingLocation ? 'Rilevo...' : 'Posizione',
            icon: Icons.my_location_rounded,
            selected: usingRealLocation,
            onTap: isLoadingLocation || isLoading ? null : useCurrentLocation,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _modeButton(
            label: isSelectingPoint ? 'Tocca mappa' : 'Scegli punto',
            icon: Icons.add_location_alt_rounded,
            selected: isSelectingPoint,
            onTap: isLoading ? null : enableManualPointSelection,
          ),
        ),
      ],
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: selected ? primaryBlue : softBlue,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? primaryBlue : const Color(0xFFD6E6EF),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? Colors.white : primaryBlue,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : primaryBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSearchInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: softOrange,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_rounded, color: orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$searchCenterLabel • $searchMode • $selectedRadius km',
              style: const TextStyle(
                color: darkBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterChip('Tutti', 'none', Icons.grid_view_rounded),
          _filterChip('Ho solo 2 ore', 'two_hours', Icons.schedule_rounded),
          _filterChip('Budget', 'budget', Icons.savings_rounded),
          _filterChip('Posti nascosti', 'hidden', Icons.explore_rounded),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, IconData icon) {
    final bool selected = selectedFilter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 17,
          color: selected ? Colors.white : primaryBlue,
        ),
        label: Text(label),
        selected: selected,
        labelStyle: TextStyle(
          color: selected ? Colors.white : darkBlue,
          fontWeight: FontWeight.w700,
        ),
        selectedColor: primaryBlue,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? primaryBlue : const Color(0xFFDDE8EF),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        onSelected: isLoading
            ? null
            : (_) {
          applyFilter(value);
        },
      ),
    );
  }

  Widget _buildMapCard() {
    final initialLat = selectedLatitude ?? 41.9028;
    final initialLng = selectedLongitude ?? 12.4964;

    return Container(
      height: 340,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(initialLat, initialLng),
              zoom: canUseApp ? _zoomForRadius() : 6,
            ),
            onMapCreated: (controller) {
              mapController = controller;
              _animateMapToCurrentArea();
            },
            onTap: selectPointOnMap,
            markers: _buildMarkers(),
            circles: _buildCircles(),
            myLocationEnabled: usingRealLocation,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
              ),
            },
          ),
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_rounded, color: primaryBlue, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    selectedMunicipalityName ?? 'Seleziona punto',
                    style: const TextStyle(
                      color: darkBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 14,
            child: InkWell(
              onTap: isLoading ? null : enableManualPointSelection,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelectingPoint ? orange : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      color: isSelectingPoint ? Colors.white : primaryBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSelectingPoint ? 'Tocca mappa' : 'Scegli punto',
                      style: TextStyle(
                        color: isSelectingPoint ? Colors.white : darkBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isSelectingPoint)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: orange.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Muovi la mappa con le dita e tocca il punto da analizzare',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          if (isLoading)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                color: orange,
                backgroundColor: softBlue,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlacesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Attrazioni trovate',
              style: TextStyle(
                color: darkBlue,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: softOrange,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${places.length}',
              style: const TextStyle(
                color: orange,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesList() {
    if (isLoading && places.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: CircularProgressIndicator(color: primaryBlue),
        ),
      );
    }

    if (errorMessage != null && places.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.redAccent,
          ),
        ),
      );
    }

    if (places.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Nessuna attrazione trovata nel raggio selezionato.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: List.generate(places.length, (index) {
        final place = places[index];
        return _buildPlaceCard(place, index);
      }),
    );
  }

  Widget _buildPlaceCard(Place place, int index) {
    final ratingText = place.rating > 0 ? place.rating.toStringAsFixed(1) : '-';
    final distanceText = place.distanzaKm == null
        ? 'Distanza n.d.'
        : '${place.distanzaKm!.toStringAsFixed(2)} km';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlaceDetailPage(placeId: place.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildPlacePreviewImage(place),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: darkBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      place.categoria,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        _smallBadge(
                          icon: Icons.star_rounded,
                          text: ratingText,
                          color: orange,
                        ),
                        const SizedBox(width: 7),
                        _smallBadge(
                          icon: Icons.near_me_rounded,
                          text: distanceText,
                          color: primaryBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: primaryBlue,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlacePreviewImage(Place place) {
    return FutureBuilder<String?>(
      future: _getPreviewImageForPlace(place),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildImagePlaceholder(
            child: const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          );
        }

        if (imageUrl == null || imageUrl.isEmpty) {
          return _buildImagePlaceholder(
            child: const Icon(
              Icons.photo_camera_back_rounded,
              color: Colors.white,
              size: 34,
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.network(
            imageUrl,
            height: 86,
            width: 86,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildImagePlaceholder(
                child: const Icon(
                  Icons.photo_camera_back_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder({required Widget child}) {
    return Container(
      height: 86,
      width: 86,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [orange, primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(child: child),
    );
  }

  Widget _smallBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: errorMessage == null ? softBlue : softOrange,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                errorMessage == null
                    ? Icons.travel_explore_rounded
                    : Icons.lock_outline_rounded,
                color: errorMessage == null ? primaryBlue : orange,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage ??
                  'Scegli una modalità per iniziare: posizione attuale, punto sulla mappa oppure cerca un Comune dal campo in alto.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: errorMessage == null ? darkBlue : Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'La mappa, le attrazioni e gli itinerari saranno disponibili solo nei Comuni presenti nell’app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSelectionHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: softOrange,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text(
          'Seleziona un punto sulla mappa. Se il Comune non è presente nell’app, comparirà un avviso.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: darkBlue,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingItineraryButton() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 18,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: isGeneratingItinerary || isLoading
                ? null
                : showGenerateItineraryDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              disabledBackgroundColor: primaryBlue.withOpacity(0.45),
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: isGeneratingItinerary
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.route_rounded, color: Colors.white),
            label: Text(
              isGeneratingItinerary
                  ? 'Creo itinerario...'
                  : 'Genera itinerario',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}