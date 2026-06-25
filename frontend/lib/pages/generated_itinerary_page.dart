import 'dart:math';
import '../widgets/easytour_header.dart';
import 'package:flutter/material.dart';

import '../models/itinerary_stop.dart';
import '../models/place.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'place_detail_page.dart';
import '../widgets/add_stop_sheet.dart';

class GeneratedItineraryPage extends StatefulWidget {
  final List<ItineraryStop> initialStops;
  final List<Place> availablePlaces;
  final String filterType;
  final int numeroGiorni;
  final int durataStimataMinuti;
  final int minutiDisponibiliAlGiorno;
  final String municipalityId;
  final String municipalityName;

  // Centro di ricerca (Comune / posizione attuale / punto scelto sulla mappa).
  // È il punto di partenza usato dall'algoritmo Nearest Neighbor per ordinare
  // le tappe di OGNI giorno.
  final double centerLatitude;
  final double centerLongitude;

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
    required this.centerLatitude,
    required this.centerLongitude,
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

  // ---------------------------------------------------------------------------
  // NEAREST NEIGHBOR
  //
  // Dato un insieme di tappe, le ordina con l'euristica del vicino più vicino
  // (Nearest Neighbor) partendo dal centro di ricerca:
  //   1. si parte dal centro (centerLatitude/centerLongitude);
  //   2. tra le tappe non ancora visitate si sceglie quella a distanza
  //      haversine minima dal punto corrente;
  //   3. la si aggiunge al percorso e diventa il nuovo punto corrente;
  //   4. si ripete finché non restano tappe.
  // Restituisce le tappe riordinate (senza ricalcolare tempi/distanze: quello
  // avviene a valle, in _rebuildTimings).
  // ---------------------------------------------------------------------------
  List<ItineraryStop> _nearestNeighborOrder(List<ItineraryStop> dayStops) {
    if (dayStops.length <= 1) {
      return List<ItineraryStop>.from(dayStops);
    }

    final remaining = List<ItineraryStop>.from(dayStops);
    final ordered = <ItineraryStop>[];

    // Punto di partenza: il centro di ricerca.
    double currentLat = widget.centerLatitude;
    double currentLng = widget.centerLongitude;

    while (remaining.isNotEmpty) {
      int bestIndex = 0;
      double bestDistance = double.infinity;

      for (int i = 0; i < remaining.length; i++) {
        final place = remaining[i].place;
        final distance = _calculateDistanceKm(
          currentLat,
          currentLng,
          place.latitudine,
          place.longitudine,
        );

        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = i;
        }
      }

      final chosen = remaining.removeAt(bestIndex);
      ordered.add(chosen);

      currentLat = chosen.place.latitudine;
      currentLng = chosen.place.longitudine;
    }

    return ordered;
  }

  // Dato un giorno e la sua lista di tappe già ordinate, ricalcola distanze,
  // tempi di arrivo e di visita. La prima tappa parte dal centro di ricerca,
  // quindi ha anch'essa un tempo di arrivo dal centro.
  List<ItineraryStop> _rebuildTimings({
    required List<ItineraryStop> orderedDayStops,
    required int day,
    required int startOrder,
  }) {
    final result = <ItineraryStop>[];

    double previousLat = widget.centerLatitude;
    double previousLng = widget.centerLongitude;
    int order = startOrder;

    for (final stop in orderedDayStops) {
      final place = stop.place;

      final distanceKm = _calculateDistanceKm(
        previousLat,
        previousLng,
        place.latitudine,
        place.longitudine,
      );

      final arrivalMinutes = _estimateArrivalMinutes(distanceKm);
      final visitMinutes = _estimateVisitTimeMinutes(place);

      result.add(
        stop.copyWith(
          ordine: order,
          giorno: day,
          tempoArrivoStimato: arrivalMinutes,
          tempoVisitaStimato: visitMinutes,
          tempoPausaStimato: 0,
          distanzaDalPuntoPrecedenteKm:
          double.parse(distanceKm.toStringAsFixed(2)),
        ),
      );

      order++;
      previousLat = place.latitudine;
      previousLng = place.longitudine;
    }

    return result;
  }

  // Generazione iniziale: distribuisce le tappe nei giorni rispettando il
  // monte ore giornaliero e, per ciascun giorno, le ordina con Nearest
  // Neighbor a partire dal centro di ricerca.
  void _recalculateItinerary() {
    if (stops.isEmpty) return;

    // 1) Assegnazione delle tappe ai giorni rispettando il tempo disponibile.
    //    L'ordine di scorrimento è quello in arrivo da SearchPage.
    final stopsByDay = <int, List<ItineraryStop>>{};
    for (int day = 1; day <= widget.numeroGiorni; day++) {
      stopsByDay[day] = [];
    }

    int currentDay = 1;
    int usedMinutesInCurrentDay = 0;

    double previousLat = widget.centerLatitude;
    double previousLng = widget.centerLongitude;

    for (final stop in stops) {
      final place = stop.place;

      final distanceKm = _calculateDistanceKm(
        previousLat,
        previousLng,
        place.latitudine,
        place.longitudine,
      );
      final arrivalMinutes = _estimateArrivalMinutes(distanceKm);
      final visitMinutes = _estimateVisitTimeMinutes(place);
      final stopBaseMinutes = arrivalMinutes + visitMinutes;

      if (currentDay < widget.numeroGiorni &&
          usedMinutesInCurrentDay > 0 &&
          usedMinutesInCurrentDay + stopBaseMinutes >
              widget.minutiDisponibiliAlGiorno) {
        currentDay++;
        usedMinutesInCurrentDay = 0;
        // All'inizio di un nuovo giorno si riparte dal centro.
        previousLat = widget.centerLatitude;
        previousLng = widget.centerLongitude;
      }

      stopsByDay[currentDay]!.add(stop);

      usedMinutesInCurrentDay += stopBaseMinutes;
      previousLat = place.latitudine;
      previousLng = place.longitudine;
    }

    // 2) Per ogni giorno: Nearest Neighbor dal centro + ricalcolo tempi.
    final rebuilt = <ItineraryStop>[];
    int globalOrder = 1;

    for (int day = 1; day <= widget.numeroGiorni; day++) {
      final dayStops = stopsByDay[day]!;
      if (dayStops.isEmpty) continue;

      final ordered = _nearestNeighborOrder(dayStops);
      final timed = _rebuildTimings(
        orderedDayStops: ordered,
        day: day,
        startOrder: globalOrder,
      );

      rebuilt.addAll(timed);
      globalOrder += timed.length;
    }

    stops = rebuilt;
    _redistributePauses();
  }

  // Ricalcolo dopo modifiche manuali (sposta giorno / rimuovi / riordina).
  // Rispetta l'assegnazione ai giorni decisa dall'utente, ma applica comunque
  // Nearest Neighbor dal centro all'interno di ciascun giorno, così il
  // percorso resta sempre coerente con l'algoritmo richiesto.
  void _recalculateManualDays() {
    if (stops.isEmpty) return;

    final rebuilt = <ItineraryStop>[];
    int globalOrder = 1;

    for (int day = 1; day <= widget.numeroGiorni; day++) {
      final dayStops = stops.where((stop) => stop.giorno == day).toList();
      if (dayStops.isEmpty) continue;

      final ordered = _nearestNeighborOrder(dayStops);
      final timed = _rebuildTimings(
        orderedDayStops: ordered,
        day: day,
        startOrder: globalOrder,
      );

      rebuilt.addAll(timed);
      globalOrder += timed.length;
    }

    stops = rebuilt;
    _redistributePauses();
  }

  void _redistributePauses() {
    final updatedStops = <ItineraryStop>[];

    for (int day = 1; day <= widget.numeroGiorni; day++) {
      final dayStops = stops.where((stop) => stop.giorno == day).toList();

      if (dayStops.isEmpty) continue;

      final usedWithoutPauses = dayStops.fold<int>(
        0,
            (sum, stop) => sum + stop.tempoArrivoStimato + stop.tempoVisitaStimato,
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
    setState(() {
      stops.removeWhere((stop) => _stopKey(stop) == stopKey);
      _recalculateManualDays();
    });
  }

  void _moveStopUpById(String stopKey) {
    setState(() {
      final index = stops.indexWhere((stop) => _stopKey(stop) == stopKey);

      if (index <= 0) return;

      final currentDay = stops[index].giorno;
      final previousIndex = index - 1;

      if (stops[previousIndex].giorno != currentDay) return;

      final temp = stops[previousIndex];
      stops[previousIndex] = stops[index];
      stops[index] = temp;

      // Nota: l'ordine manuale su/giù viene comunque normalizzato da
      // Nearest Neighbor dentro lo stesso giorno.
      _recalculateManualDays();
    });
  }

  void _moveStopDownById(String stopKey) {
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
    setState(() {
      final index = stops.indexWhere((stop) => _stopKey(stop) == stopKey);

      if (index == -1) return;

      stops[index] = stops[index].copyWith(giorno: day);
      _recalculateManualDays();
    });
  }

  void _addStop(Place place, int selectedDay) {
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${place.nome} aggiunto al giorno $selectedDay.'),
      ),
    );
  }

  Future<void> _showAddStopSheet() async {
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddStopSheet(
          availablePlaces: widget.availablePlaces,
          numeroGiorni: widget.numeroGiorni,
        ),
      );

      if (result == null) return;
      if (!mounted) return;

      final place = result['place'] as Place;
      final day = result['day'] as int;

      _addStop(place, day);
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

    final userId = SessionService.currentUserId;

    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Utente non loggato. Effettua di nuovo il login prima di salvare.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final itineraryId = await apiService.saveItinerary(
        userId: userId,
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
            'Itinerario salvato correttamente. ID: $itineraryId',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore nel salvataggio dell’itinerario: $e',
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
    if (category.contains('museo')) return 60;
    if (category.contains('castle')) return 60;
    if (category.contains('castello')) return 60;
    if (category.contains('church')) return 45;
    if (category.contains('chiesa')) return 45;
    if (category.contains('historical')) return 45;
    if (category.contains('storico')) return 45;
    if (category.contains('landmark')) return 45;
    if (category.contains('park')) return 40;
    if (category.contains('parco')) return 40;
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
            EasyTourHeader(
              showBack: true,
              showLogout: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
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

  Widget _buildIntroBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFDDEBFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.auto_fix_high_rounded,
              color: primaryBlue,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Itinerario generato automaticamente',
                  style: TextStyle(
                    color: Color(0xFF0D1B2A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Percorso ottimizzato (vicino più vicino). Puoi rimuovere, aggiungere o spostare tappe tra i giorni.',
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
        borderRadius: BorderRadius.circular(20),
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
            title: 'Arrivo',
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
            size: 26,
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 5),
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
      height: 68,
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
                  fontSize: 14,
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
            width: 38,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Text(
                  arrivalLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 27,
                  width: 27,
                  decoration: const BoxDecoration(
                    color: primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stop.ordine.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
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
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildStopImage(stop.place),
          const SizedBox(width: 11),
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
                    const SizedBox(height: 5),
                    Text(
                      stop.place.categoria,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _miniInfoChip(
                            icon: Icons.directions_walk_rounded,
                            text: 'Arrivo ${stop.tempoArrivoStimato} min',
                            color: green,
                          ),
                          const SizedBox(width: 6),
                          _miniInfoChip(
                            icon: Icons.schedule_rounded,
                            text: 'Durata ${stop.tempoVisitaStimato} min',
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          _miniInfoChip(
                            icon: Icons.coffee_rounded,
                            text: 'Pausa ${stop.tempoPausaStimato} min',
                            color: orange,
                          ),
                        ],
                      ),
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
                  size: 27,
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
                  size: 27,
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

                  if (value == 'delete') {
                    _removeStopById(_stopKey(stop));
                  }
                },
                itemBuilder: (context) {
                  return [
                    ...List.generate(widget.numeroGiorni, (dayIndex) {
                      final selectedDay = dayIndex + 1;

                      return PopupMenuItem(
                        value: 'day_$selectedDay',
                        child: Text('Sposta al giorno $selectedDay'),
                      );
                    }),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: dangerRed,
                          ),
                          SizedBox(width: 8),
                          Text('Rimuovi tappa'),
                        ],
                      ),
                    ),
                  ];
                },
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

  String _resolveImageUrl(String url) {
    if (url.startsWith('https://upload.wikimedia.org/')) {
      final encoded = Uri.encodeComponent(url);
      return '${ApiService.baseUrl}/wiki/image-proxy?url=$encoded';
    }
    return url;
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
                size: 30,
              ),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              _resolveImageUrl(imageUrl),
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              // gli headers User-Agent qui non servono più per le Wiki
              // (le serve già il proxy), ma puoi lasciarli per le altre fonti
              errorBuilder: (_, __, ___) {
                debugPrint('IMG FALLITA: $imageUrl');
                return _placeholderImage(
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 30,
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
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [orange, primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
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
                  : 'Ogni giorno parte dal punto di ricerca e segue il percorso più vicino. Gli orari si aggiornano dopo ogni modifica.',
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