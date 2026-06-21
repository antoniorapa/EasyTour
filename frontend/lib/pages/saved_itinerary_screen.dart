import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/easytour_header.dart';
import 'itinerary_detail_screen.dart';
import 'login_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL TAPPA SALVATA
// ─────────────────────────────────────────────────────────────────────────────

class SavedItineraryStop {
  final String id;
  final int ordine;
  final int giorno;
  final int tempoArrivoStimato;
  final int tempoVisitaStimato;
  final int tempoPausaStimato;
  final double distanzaDalPuntoPrecedenteKm;

  final String placeId;
  final String placeName;
  final String placeAddress;
  final String placeCategory;
  final String imageUrl;
  final double rating;
  final int reviewsCount;
  final String description;
  final double latitude;
  final double longitude;

  const SavedItineraryStop({
    required this.id,
    required this.ordine,
    required this.giorno,
    required this.tempoArrivoStimato,
    required this.tempoVisitaStimato,
    required this.tempoPausaStimato,
    required this.distanzaDalPuntoPrecedenteKm,
    required this.placeId,
    required this.placeName,
    required this.placeAddress,
    required this.placeCategory,
    required this.imageUrl,
    required this.rating,
    required this.reviewsCount,
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  factory SavedItineraryStop.fromJson(Map<String, dynamic> json) {
    final placeRaw = json['place'] ?? json['luogo'] ?? json['attrazione'];
    final place = placeRaw is Map<String, dynamic> ? placeRaw : json;

    return SavedItineraryStop(
      id: _asString(json['id'] ?? json['stopId'] ?? place['id']),
      ordine: _asInt(json['ordine'] ?? json['order'], fallback: 1),
      giorno: _asInt(json['giorno'] ?? json['day'], fallback: 1),
      tempoArrivoStimato: _asInt(
        json['tempoArrivoStimato'] ??
            json['arrivalMinutes'] ??
            json['tempoArrivo'] ??
            0,
        fallback: 0,
      ),
      tempoVisitaStimato: _asInt(
        json['tempoVisitaStimato'] ??
            json['visitMinutes'] ??
            json['estimatedMinutes'] ??
            json['durata'] ??
            40,
        fallback: 40,
      ),
      tempoPausaStimato: _asInt(
        json['tempoPausaStimato'] ?? json['pauseMinutes'] ?? 0,
        fallback: 0,
      ),
      distanzaDalPuntoPrecedenteKm: _asDouble(
        json['distanzaDalPuntoPrecedenteKm'] ?? json['distanceKm'],
        fallback: 0,
      ),
      placeId: _asString(place['id'] ?? place['placeId']),
      placeName: _asString(
        place['nome'] ?? place['name'] ?? place['placeName'] ?? 'Luogo',
      ),
      placeAddress: _asString(
        place['indirizzo'] ?? place['address'] ?? place['placeAddress'],
      ),
      placeCategory: _asString(
        place['categoria'] ?? place['category'] ?? place['placeCategory'],
      ),
      imageUrl: _asString(
        place['immagineUrl'] ?? place['imageUrl'] ?? place['photoUrl'],
      ),
      rating: _asDouble(place['rating'] ?? place['valutazione'], fallback: 0),
      reviewsCount: _asInt(
        place['numeroRecensioni'] ?? place['reviewsCount'],
        fallback: 0,
      ),
      description: _asString(
        place['descrizione'] ??
            place['description'] ??
            'Descrizione non disponibile.',
      ),
      latitude: _asDouble(
        place['latitudine'] ?? place['latitude'] ?? place['lat'],
        fallback: 0,
      ),
      longitude: _asDouble(
        place['longitudine'] ?? place['longitude'] ?? place['lng'],
        fallback: 0,
      ),
    );
  }

  static String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static double _asDouble(dynamic value, {required double fallback}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL ITINERARIO SALVATO
// ─────────────────────────────────────────────────────────────────────────────

class SavedItinerary {
  final String id;
  final String title;
  final String municipality;
  final int days;
  final int stopsCount;
  final DateTime createdAt;
  final String? filter;
  final List<SavedItineraryStop> stops;

  const SavedItinerary({
    required this.id,
    required this.title,
    required this.municipality,
    required this.days,
    required this.stopsCount,
    required this.createdAt,
    required this.stops,
    this.filter,
  });

  factory SavedItinerary.fromJson(Map<String, dynamic> json) {
    final parsedStops = _parseStops(json['stops'] ?? json['tappe']);
    final rawStopsCount = json['stopsCount'] ?? json['numeroTappe'];

    return SavedItinerary(
      id: _asString(json['id'] ?? json['itineraryId']),
      title: _asString(
        json['title'] ??
            json['titolo'] ??
            json['nome'] ??
            'Itinerario senza titolo',
      ),
      municipality: _asString(
        json['municipality'] ??
            json['municipalityName'] ??
            json['comune'] ??
            json['nomeComune'] ??
            'Comune non disponibile',
      ),
      days: _asInt(json['days'] ?? json['numeroGiorni'], fallback: 1),
      stopsCount: parsedStops.isNotEmpty
          ? parsedStops.length
          : _asInt(rawStopsCount, fallback: 0),
      createdAt: _parseDate(
        json['createdAt'] ??
            json['dataCreazione'] ??
            json['created_at'] ??
            json['date'],
      ),
      filter: _normalizeFilter(
        json['filter'] ??
            json['filterType'] ??
            json['filtro'] ??
            json['filtroUtilizzato'],
      ),
      stops: parsedStops,
    );
  }

  static List<SavedItineraryStop> _parseStops(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map<String, dynamic>>()
        .map((item) => SavedItineraryStop.fromJson(item))
        .toList()
      ..sort((a, b) {
        final dayCompare = a.giorno.compareTo(b.giorno);
        if (dayCompare != 0) return dayCompare;
        return a.ordine.compareTo(b.ordine);
      });
  }

  static String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    if (value is Map<String, dynamic>) {
      final year = _asInt(value['year'], fallback: DateTime.now().year);
      final month = _asInt(value['month'], fallback: DateTime.now().month);
      final day = _asInt(value['day'], fallback: DateTime.now().day);
      final hour = _asInt(value['hour'], fallback: 0);
      final minute = _asInt(value['minute'], fallback: 0);

      return DateTime(year, month, day, hour, minute);
    }

    return DateTime.now();
  }

  static String? _normalizeFilter(dynamic value) {
    if (value == null) return null;

    final filter = value.toString().trim();

    if (filter.isEmpty || filter == 'none' || filter == 'Nessun filtro') {
      return null;
    }

    switch (filter) {
      case 'two_hours':
      case 'Ho solo 2 ore':
        return 'Ho solo 2 ore';

      case 'budget':
      case 'Budget limitato':
        return 'Budget limitato';

      case 'hidden':
      case 'Posti nascosti':
        return 'Posti nascosti';

      default:
        return filter;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SavedItinerariesScreen extends StatefulWidget {
  const SavedItinerariesScreen({super.key});

  @override
  State<SavedItinerariesScreen> createState() => _SavedItinerariesScreenState();
}

class _SavedItinerariesScreenState extends State<SavedItinerariesScreen> {
  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color softBlue = Color(0xFFEAF4FA);
  static const Color green = Color(0xFF00A676);
  static const Color dangerRed = Color(0xFFE53935);

  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  List<SavedItinerary> _itineraries = [];

  @override
  void initState() {
    super.initState();
    _loadMyItineraries();
  }

  Future<void> _loadMyItineraries() async {
    final userId = SessionService.currentUserId;

    if (userId == null || userId.trim().isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
        'Utente non loggato. Effettua il login per visualizzare i tuoi itinerari.';
        _itineraries = [];
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.getMyItineraries(userId);

      final loadedItineraries = result
          .whereType<Map<String, dynamic>>()
          .map((item) => SavedItinerary.fromJson(item))
          .toList();

      loadedItineraries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;

      setState(() {
        _itineraries = loadedItineraries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Errore durante il caricamento degli itinerari: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      '',
      'gen',
      'feb',
      'mar',
      'apr',
      'mag',
      'giu',
      'lug',
      'ago',
      'set',
      'ott',
      'nov',
      'dic',
    ];

    return '${d.day} ${months[d.month]} ${d.year}';
  }

  String _formatFilterLabel(String? filter) {
    if (filter == null || filter.trim().isEmpty) return 'Tutti';
    return filter;
  }

  Color _filterColor(String? filter) {
    switch (filter) {
      case 'Ho solo 2 ore':
        return const Color(0xFFFEF3C7);
      case 'Budget limitato':
        return const Color(0xFFDCFCE7);
      case 'Posti nascosti':
        return const Color(0xFFEDE9FE);
      default:
        return softBlue;
    }
  }

  Color _filterTextColor(String? filter) {
    switch (filter) {
      case 'Ho solo 2 ore':
        return const Color(0xFF92400E);
      case 'Budget limitato':
        return const Color(0xFF166534);
      case 'Posti nascosti':
        return const Color(0xFF5B21B6);
      default:
        return primaryBlue;
    }
  }

  int get _totalStops {
    return _itineraries.fold<int>(
      0,
          (sum, itinerary) => sum + itinerary.stopsCount,
    );
  }

  int get _totalDays {
    return _itineraries.fold<int>(
      0,
          (sum, itinerary) => sum + itinerary.days,
    );
  }

  Future<void> _logout() async {
    await SessionService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
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
              showLogout: true,
              onLogoutTap: _logout,
            ),
            Expanded(
              child: RefreshIndicator(
                color: primaryBlue,
                onRefresh: _loadMyItineraries,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
        children: const [
          Center(
            child: CircularProgressIndicator(color: primaryBlue),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return _buildError();
    }

    if (_itineraries.isEmpty) {
      return _buildEmpty();
    }

    return _buildList();
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
              Icons.bookmark_added_rounded,
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
                  'I tuoi itinerari salvati',
                  style: TextStyle(
                    color: Color(0xFF0D1B2A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Rivedi i percorsi creati e apri il dettaglio delle tappe salvate.',
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
            icon: Icons.route_rounded,
            iconColor: primaryBlue,
            title: 'Itinerari',
            value: '${_itineraries.length}',
          ),
          _verticalDivider(),
          _statItem(
            icon: Icons.place_rounded,
            iconColor: orange,
            title: 'Luoghi',
            value: '$_totalStops',
          ),
          _verticalDivider(),
          _statItem(
            icon: Icons.calendar_today_rounded,
            iconColor: green,
            title: 'Giorni',
            value: '$_totalDays',
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
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
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

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildIntroBox(),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: dangerRed,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Impossibile caricare gli itinerari',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: darkBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _loadMyItineraries,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Riprova',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildIntroBox(),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.map_outlined,
                  color: primaryBlue,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Nessun itinerario salvato',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: darkBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Genera un itinerario da una città attiva e salvalo per ritrovarlo qui.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildIntroBox(),
        const SizedBox(height: 16),
        _buildStatsBox(),
        const SizedBox(height: 22),
        const Text(
          'Percorsi salvati',
          style: TextStyle(
            color: darkBlue,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(_itineraries.length, (index) {
          final itinerary = _itineraries[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ItineraryCard(
              itinerary: itinerary,
              filterBg: _filterColor(itinerary.filter),
              filterFg: _filterTextColor(itinerary.filter),
              formattedDate: _formatDate(itinerary.createdAt),
              filterLabel: _formatFilterLabel(itinerary.filter),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItineraryDetailScreen(
                      itinerary: itinerary,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ItineraryCard extends StatelessWidget {
  final SavedItinerary itinerary;
  final Color filterBg;
  final Color filterFg;
  final String filterLabel;
  final String formattedDate;
  final VoidCallback onTap;

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color orange = Color(0xFFF58A00);
  static const Color softBlue = Color(0xFFEAF4FA);

  const _ItineraryCard({
    required this.itinerary,
    required this.filterBg,
    required this.filterFg,
    required this.filterLabel,
    required this.formattedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(12),
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
            children: [
              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [orange, primaryBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itinerary.title,
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
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: primaryBlue,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            itinerary.municipality,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _SmallInfoChip(
                            icon: Icons.calendar_today_rounded,
                            text:
                            '${itinerary.days} ${itinerary.days == 1 ? "giorno" : "giorni"}',
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 5),
                          _SmallInfoChip(
                            icon: Icons.place_rounded,
                            text:
                            '${itinerary.stopsCount} ${itinerary.stopsCount == 1 ? "luogo" : "luoghi"}',
                            color: orange,
                          ),
                          const SizedBox(width: 5),
                          _FilterChip(
                            label: filterLabel,
                            bg: filterBg,
                            fg: filterFg,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Salvato il $formattedDate',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8A94A6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: primaryBlue,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SmallInfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _FilterChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}