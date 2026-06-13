import 'dart:math';

import 'package:flutter/material.dart';

import '../models/itinerary_stop.dart';
import '../models/place.dart';
import '../services/api_service.dart';
import 'place_detail_page.dart';

class GeneratedItineraryPage extends StatefulWidget {
  final List<ItineraryStop> initialStops;
  final List<Place> availablePlaces;
  final String filterType;
  final int numeroGiorni;
  final int durataStimataMinuti;
  final int minutiDisponibiliAlGiorno;
  final String municipalityId;
  final String municipalityName;

  const GeneratedItineraryPage({
    super.key,
    required this.initialStops,
    required this.availablePlaces,
    required this.filterType,
    required this.numeroGiorni,
    required this.durataStimataMinuti,
    required this.minutiDisponibiliAlGiorno,
    required this.municipalityId,
    required this.municipalityName,
  });

  @override
  State<GeneratedItineraryPage> createState() => _GeneratedItineraryPageState();
}

class _GeneratedItineraryPageState extends State<GeneratedItineraryPage> {
  final ApiService apiService = ApiService();

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color softBlue = Color(0xFFEAF4FA);
  static const Color softOrange = Color(0xFFFFF2DF);
  static const Color dangerRed = Color(0xFFE53935);
  static const Color green = Color(0xFF00A676);

  late List<ItineraryStop> stops;

  bool isSaving = false;
  bool isSearchingPlaces = false;

  List<Place> searchResults = [];

  final Map<String, Future<String?>> _previewImageCache = {};

  @override
  void initState() {
    super.initState();
    stops = widget.initialStops.map((stop) => stop.copyWith()).toList();
    _recalculateItinerary();
  }

  int get maxTotalMinutes {
    return widget.numeroGiorni * widget.minutiDisponibiliAlGiorno;
  }

  int get totalMinutes {
    return stops.fold<int>(
      0,
          (sum, stop) =>
      sum +
          stop.tempoArrivoStimato +
          stop.tempoVisitaStimato +
          stop.tempoPausaStimato,
    );
  }

  int get walkingMinutes {
    return stops.fold<int>(
      0,
          (sum, stop) => sum + stop.tempoArrivoStimato,
    );
  }

  int get pauseMinutes {
    return stops.fold<int>(
      0,
          (sum, stop) => sum + stop.tempoPausaStimato,
    );
  }

  bool get isOverLimit {
    return totalMinutes > maxTotalMinutes;
  }

  Map<int, int> get minutesByDay {
    final result = <int, int>{};

    for (int day = 1; day <= widget.numeroGiorni; day++) {
      result[day] = 0;
    }

    for (final stop in stops) {
      result[stop.giorno] = (result[stop.giorno] ?? 0) +
          stop.tempoArrivoStimato +
          stop.tempoVisitaStimato +
          stop.tempoPausaStimato;
    }

    return result;
  }

  List<ItineraryStop> _stopsForDay(int day) {
    return stops.where((stop) => stop.giorno == day).toList();
  }

  String _stopKey(ItineraryStop stop) {
    return stop.place.id;
  }

  void _recalculateItinerary() {
    if (stops.isEmpty) return;

    final recalculatedStops = <ItineraryStop>[];

    int currentDay = 1;
    int usedMinutesInCurrentDay = 0;
    int globalOrder = 1;

    double? previousLat;
    double? previousLng;

    for (final oldStop in stops) {
      final place = oldStop.place;

      double distanceKm = 0;
      int arrivalMinutes = 0;

      if (previousLat != null && previousLng != null) {
        distanceKm = _calculateDistanceKm(
          previousLat,
          previousLng,
          place.latitudine,
          place.longitudine,
        );

        arrivalMinutes = _estimateArrivalMinutes(distanceKm);
      }

      final visitMinutes = _estimateVisitTimeMinutes(place);
      final stopBaseMinutes = arrivalMinutes + visitMinutes;

      if (currentDay < widget.numeroGiorni &&
          usedMinutesInCurrentDay > 0 &&
          usedMinutesInCurrentDay + stopBaseMinutes >
              widget.minutiDisponibiliAlGiorno) {
        currentDay++;
        usedMinutesInCurrentDay = 0;
        previousLat = null;
        previousLng = null;
        distanceKm = 0;
        arrivalMinutes = 0;
      }

      recalculatedStops.add(
        oldStop.copyWith(
          ordine: globalOrder,
          giorno: currentDay,
          tempoArrivoStimato: arrivalMinutes,
          tempoVisitaStimato: visitMinutes,
          tempoPausaStimato: 0,
          distanzaDalPuntoPrecedenteKm:
          double.parse(distanceKm.toStringAsFixed(2)),
        ),
      );

      globalOrder++;
      usedMinutesInCurrentDay += arrivalMinutes + visitMinutes;

      previousLat = place.latitudine;
      previousLng = place.longitudine;
    }

    stops = recalculatedStops;
    _redistributePauses();
  }

  void _recalculateManualDays() {
    if (stops.isEmpty) return;

    final recalculatedStops = <ItineraryStop>[];
    int globalOrder = 1;

    for (int day = 1; day <= widget.numeroGiorni; day++) {
      final dayStops = stops.where((stop) => stop.giorno == day).toList();

      double? previousLat;
      double? previousLng;

      for (final oldStop in dayStops) {
        final place = oldStop.place;

        double distanceKm = 0;
        int arrivalMinutes = 0;

        if (previousLat != null && previousLng != null) {
          distanceKm = _calculateDistanceKm(
            previousLat,
            previousLng,
            place.latitudine,
            place.longitudine,
          );

          arrivalMinutes = _estimateArrivalMinutes(distanceKm);
        }

        recalculatedStops.add(
          oldStop.copyWith(
            ordine: globalOrder,
            giorno: day,
            tempoArrivoStimato: arrivalMinutes,
            tempoVisitaStimato: _estimateVisitTimeMinutes(place),
            distanzaDalPuntoPrecedenteKm:
            double.parse(distanceKm.toStringAsFixed(2)),
            tempoPausaStimato: 0,
          ),
        );

        globalOrder++;
        previousLat = place.latitudine;
        previousLng = place.longitudine;
      }
    }

    stops = recalculatedStops;
    _redistributePauses();
  }

  void _redistributePauses() {
    final updatedStops = <ItineraryStop>[];

    for (int day = 1; day <= widget.numeroGiorni; day++) {
      final dayStops = stops.where((stop) => stop.giorno == day).toList();

      if (dayStops.isEmpty) continue;

      final usedWithoutPauses = dayStops.fold<int>(
        0,
            (sum, stop) =>
        sum + stop.tempoArrivoStimato + stop.tempoVisitaStimato,
      );

      final remainingMinutes =
          widget.minutiDisponibiliAlGiorno - usedWithoutPauses;

      final pausePerStop = remainingMinutes > 0
          ? min(20, (remainingMinutes / dayStops.length).floor())
          : 0;

      for (final stop in dayStops) {
        updatedStops.add(
          stop.copyWith(
            tempoPausaStimato: pausePerStop,
          ),
        );
      }
    }

    updatedStops.sort((a, b) => a.ordine.compareTo(b.ordine));
    stops = updatedStops;
  }

  void _removeStopById(String stopKey) {
    if (!mounted) return;

    setState(() {
      stops.removeWhere((stop) => _stopKey(stop) == stopKey);
      _recalculateManualDays();
    });
  }

  void _moveStopUpById(String stopKey) {
    if (!mounted) return;

    setState(() {
      final index = stops.indexWhere((stop) => _stopKey(stop) == stopKey);

      if (index <= 0) return;

      final currentDay = stops[index].giorno;
      final previousIndex = index - 1;

      if (stops[previousIndex].giorno != currentDay) return;

      final temp = stops[previousIndex];
      stops[previousIndex] = stops[index];
      stops[index] = temp;

      _recalculateManualDays();
    });
  }

  void _moveStopDownById(String stopKey) {
    if (!mounted) return;

    setState(() {
      final index = stops.indexWhere((stop) => _stopKey(stop) == stopKey);

      if (index == -1 || index >= stops.length - 1) return;

      final currentDay = stops[index].giorno;
      final nextIndex = index + 1;

      if (stops[nextIndex].giorno != currentDay) return;

      final temp = stops[nextIndex];
      stops[nextIndex] = stops[index];
      stops[index] = temp;

      _recalculateManualDays();
    });
  }

  void _moveStopToDay(String stopKey, int day) {
    if (!mounted) return;

    setState(() {
      final index = stops.indexWhere((stop) => _stopKey(stop) == stopKey);

      if (index == -1) return;

      stops[index] = stops[index].copyWith(giorno: day);
      _recalculateManualDays();
    });
  }

  void _addStop(Place place, int selectedDay) {
    if (!mounted) return;

    final alreadyExists = stops.any((stop) => stop.place.id == place.id);

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Questa tappa è già presente nell’itinerario.'),
        ),
      );
      return;
    }

    setState(() {
      stops.add(
        ItineraryStop(
          ordine: stops.length + 1,
          giorno: selectedDay,
          tempoVisitaStimato: _estimateVisitTimeMinutes(place),
          tempoArrivoStimato: 0,
          tempoPausaStimato: 0,
          distanzaDalPuntoPrecedenteKm: 0,
          place: place,
        ),
      );

      _recalculateManualDays();
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${place.nome} aggiunto al giorno $selectedDay.'),
      ),
    );
  }

  Future<void> _showAddStopSheet() async {
    int selectedDay = 1;
    final TextEditingController searchController = TextEditingController();

    searchResults = widget.availablePlaces;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> runSearch(String value) async {
              setModalState(() {
                isSearchingPlaces = true;
              });

              try {
                final cleanQuery = value.trim();

                if (cleanQuery.isEmpty) {
                  searchResults = widget.availablePlaces;
                } else {
                  searchResults =
                  await apiService.searchGooglePlacesText(cleanQuery);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Errore nella ricerca: $e'),
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setModalState(() {
                    isSearchingPlaces = false;
                  });
                }
              }
            }

            return Container(
              decoration: const BoxDecoration(
                color: lightBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(modalContext).size.height * 0.78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        height: 5,
                        width: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD0D9E2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Aggiungi tappa',
                      style: TextStyle(
                        color: darkBlue,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Scegli il giorno e aggiungi una nuova attrazione.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedDay,
                      decoration: _inputDecoration('Giorno'),
                      items: List.generate(widget.numeroGiorni, (index) {
                        final day = index + 1;

                        return DropdownMenuItem<int>(
                          value: day,
                          child: Text('Giorno $day'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;

                        setModalState(() {
                          selectedDay = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      decoration: _inputDecoration('Cerca attrazione').copyWith(
                        hintText: 'Es. museo, castello, parco...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: primaryBlue,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward, color: orange),
                          onPressed: () {
                            runSearch(searchController.text);
                          },
                        ),
                      ),
                      onSubmitted: runSearch,
                    ),
                    const SizedBox(height: 12),
                    if (isSearchingPlaces)
                      const LinearProgressIndicator(
                        color: orange,
                        backgroundColor: softBlue,
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: searchResults.isEmpty
                          ? const Center(
                        child: Text('Nessun risultato trovato.'),
                      )
                          : ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final place = searchResults[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              title: Text(
                                place.nome,
                                style: const TextStyle(
                                  color: darkBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                _buildPlaceSubtitle(place),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: softOrange,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: orange,
                                ),
                              ),
                              onTap: () {
                                final selectedPlace = place;
                                final day = selectedDay;

                                Navigator.pop(bottomSheetContext);

                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  _addStop(selectedPlace, day);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }

  Future<void> _saveItinerary() async {
    if (stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Non ci sono tappe da salvare.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await apiService.saveItinerary(
        userId: 'user_turista_1',
        municipalityId: widget.municipalityId,
        titolo: 'Itinerario ${widget.municipalityName}',
        filterType: widget.filterType,
        numeroGiorni: widget.numeroGiorni,
        stops: stops,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Itinerario salvato e associato al Comune di ${widget.municipalityName}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore nel salvataggio. Alcune tappe Google potrebbero non essere presenti in Neo4j. Dettaglio: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
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

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '$remainingMinutes min';
    }

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}min';
  }

  String _formatClockForDayStop(List<ItineraryStop> dayStops, int localIndex) {
    int minutes = 0;

    for (int i = 0; i < localIndex; i++) {
      minutes += dayStops[i].tempoArrivoStimato;
      minutes += dayStops[i].tempoVisitaStimato;
      minutes += dayStops[i].tempoPausaStimato;
    }

    minutes += dayStops[localIndex].tempoArrivoStimato;

    const startHour = 9;
    final totalMinutes = startHour * 60 + minutes;
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _filterLabel() {
    switch (widget.filterType) {
      case 'two_hours':
        return '2 ore';
      case 'budget':
        return 'Budget';
      case 'hidden':
        return 'Nascosti';
      default:
        return 'Tutti';
    }
  }

  String _buildPlaceSubtitle(Place place) {
    final distanceText = place.distanzaKm == null
        ? ''
        : ' • ${place.distanzaKm!.toStringAsFixed(2)} km';

    final reviewText = place.numeroRecensioni > 0
        ? '${place.numeroRecensioni} recensioni'
        : 'recensioni non disponibili';

    final addressText = place.indirizzo == null || place.indirizzo!.isEmpty
        ? ''
        : '\n${place.indirizzo}';

    return '${place.categoria} • $reviewText$distanceText$addressText';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildMockupHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                children: [
                  _buildIntroBox(),
                  const SizedBox(height: 16),
                  _buildStatsBox(),
                  const SizedBox(height: 22),
                  _buildDaysTimeline(),
                  const SizedBox(height: 18),
                  _buildAddStopButton(),
                  const SizedBox(height: 18),
                  _buildInfoBox(),
                  const SizedBox(height: 18),
                  _buildSaveButton(),
                  const SizedBox(height: 10),
                  _buildFooterPrivacy(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockupHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: primaryBlue,
              size: 30,
            ),
          ),
          Expanded(
            child: Text(
              'Itinerario a ${widget.municipalityName}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: primaryBlue,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: primaryBlue,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFDDEBFF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.auto_fix_high_rounded,
              color: primaryBlue,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Itinerario generato automaticamente.',
                  style: TextStyle(
                    color: Color(0xFF0D1B2A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Puoi rimuovere, aggiungere o riordinare le tappe.',
                  style: TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _statItem(
            icon: Icons.schedule_rounded,
            iconColor: primaryBlue,
            title: 'Durata',
            value: _formatMinutes(totalMinutes),
          ),
          _verticalDivider(),
          _statItem(
            icon: Icons.directions_walk_rounded,
            iconColor: green,
            title: 'A piedi',
            value: _formatMinutes(walkingMinutes),
          ),
          _verticalDivider(),
          _statItem(
            icon: Icons.coffee_rounded,
            iconColor: orange,
            title: 'Pausa',
            value: _formatMinutes(pauseMinutes),
          ),
          _verticalDivider(),
          _statItem(
            icon: Icons.filter_alt_rounded,
            iconColor: primaryBlue,
            title: 'Filtro',
            value: _filterLabel(),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 27,
          ),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF5F6B7A),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 72,
      width: 1,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildDaysTimeline() {
    if (stops.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text('Nessuna tappa presente.'),
        ),
      );
    }

    return Column(
      children: List.generate(widget.numeroGiorni, (index) {
        final day = index + 1;
        final dayStops = _stopsForDay(day);
        final dayMinutes = minutesByDay[day] ?? 0;

        return _buildDaySection(
          day: day,
          dayStops: dayStops,
          dayMinutes: dayMinutes,
        );
      }),
    );
  }

  Widget _buildDaySection({
    required int day,
    required List<ItineraryStop> dayStops,
    required int dayMinutes,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDayHeader(day, dayMinutes),
          const SizedBox(height: 12),
          if (dayStops.isEmpty)
            _buildEmptyDayBox(day)
          else
            Column(
              children: List.generate(dayStops.length, (localIndex) {
                final stop = dayStops[localIndex];

                return _buildTimelineRow(
                  day: day,
                  dayStops: dayStops,
                  stop: stop,
                  localIndex: localIndex,
                  isLast: localIndex == dayStops.length - 1,
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(int day, int dayMinutes) {
    final overDayLimit = dayMinutes > widget.minutiDisponibiliAlGiorno;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: overDayLimit ? softOrange : softBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: overDayLimit
              ? orange.withOpacity(0.35)
              : primaryBlue.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: const BoxDecoration(
              color: primaryBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$day',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Giorno $day',
              style: const TextStyle(
                color: darkBlue,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '${_formatMinutes(dayMinutes)} / ${_formatMinutes(widget.minutiDisponibiliAlGiorno)}',
            style: TextStyle(
              color: overDayLimit ? orange : primaryBlue,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayBox(int day) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        'Nessuna tappa nel giorno $day. Puoi aggiungerne una con “Aggiungi tappa”.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTimelineRow({
    required int day,
    required List<ItineraryStop> dayStops,
    required ItineraryStop stop,
    required int localIndex,
    required bool isLast,
  }) {
    final arrivalLabel = _formatClockForDayStop(dayStops, localIndex);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Text(
                  arrivalLabel,
                  style: const TextStyle(
                    color: primaryBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!isLast) ...[
                  const Spacer(),
                  Text(
                    stop.tempoArrivoStimato <= 0
                        ? ''
                        : 'A piedi\n${stop.tempoArrivoStimato} min',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF5F6B7A),
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 38,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  height: 38,
                  width: 38,
                  decoration: const BoxDecoration(
                    color: primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stop.ordine.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: primaryBlue,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildStopCard(stop, day, localIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopCard(ItineraryStop stop, int day, int localIndex) {
    final dayStops = _stopsForDay(day);
    final isFirst = localIndex == 0;
    final isLast = localIndex == dayStops.length - 1;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildStopImage(stop.place),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaceDetailPage(
                      placeId: stop.place.id,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.place.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 15,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _miniInfoChip(
                          icon: Icons.directions_walk_rounded,
                          text: '${stop.tempoArrivoStimato} min',
                          color: green,
                        ),
                        _miniInfoChip(
                          icon: Icons.schedule_rounded,
                          text: '${stop.tempoVisitaStimato} min',
                          color: primaryBlue,
                        ),
                        _miniInfoChip(
                          icon: Icons.coffee_rounded,
                          text: '${stop.tempoPausaStimato} min',
                          color: orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minHeight: 28,
                  minWidth: 28,
                ),
                onPressed:
                isFirst ? null : () => _moveStopUpById(_stopKey(stop)),
                icon: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: isFirst ? Colors.black26 : primaryBlue,
                  size: 28,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minHeight: 28,
                  minWidth: 28,
                ),
                onPressed:
                isLast ? null : () => _moveStopDownById(_stopKey(stop)),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isLast ? Colors.black26 : primaryBlue,
                  size: 28,
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 22,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF6B7280),
                ),
                onSelected: (value) {
                  if (value.startsWith('day_')) {
                    final selectedDay =
                    int.parse(value.replaceFirst('day_', ''));
                    _moveStopToDay(_stopKey(stop), selectedDay);
                  }
                },
                itemBuilder: (context) {
                  return List.generate(widget.numeroGiorni, (dayIndex) {
                    final selectedDay = dayIndex + 1;

                    return PopupMenuItem(
                      value: 'day_$selectedDay',
                      child: Text('Sposta al giorno $selectedDay'),
                    );
                  });
                },
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minHeight: 30,
                  minWidth: 30,
                ),
                onPressed: () => _removeStopById(_stopKey(stop)),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: dangerRed,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopImage(Place place) {
    return FutureBuilder<String?>(
      future: _getPreviewImageForPlace(place),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _placeholderImage(
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          );
        }

        if (imageUrl == null || imageUrl.isEmpty) {
          return _placeholderImage(
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 32,
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: 74,
            height: 74,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return _placeholderImage(
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _placeholderImage({required Widget child}) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [orange, primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildAddStopButton() {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showAddStopSheet,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: primaryBlue,
            width: 1.7,
          ),
          foregroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(
          Icons.add_circle_outline_rounded,
          size: 24,
        ),
        label: const Text(
          'Aggiungi tappa',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: const BoxDecoration(
              color: primaryBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isOverLimit
                  ? 'Hai superato il tempo disponibile: è consentito, ma l’itinerario risulterà più lungo.'
                  : 'Gli orari di arrivo e le permanenze si aggiornano automaticamente dopo ogni modifica.',
              style: const TextStyle(
                color: Color(0xFF243B53),
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 64,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isSaving ? null : _saveItinerary,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: isSaving
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        )
            : const Icon(
          Icons.save_outlined,
          size: 30,
        ),
        label: Text(
          isSaving ? 'Salvataggio...' : 'Salva itinerario',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterPrivacy() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          color: Color(0xFF8A94A6),
          size: 18,
        ),
        SizedBox(width: 8),
        Text(
          'Itinerario salvato solo per te',
          style: TextStyle(
            color: Color(0xFF8A94A6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}