import 'package:flutter/material.dart';
import 'itinerary_detail_screen.dart';
import '../widgets/easytour_header.dart';
import 'login_page.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────────────────────────────────────

class SavedItinerary {
  final String id;
  final String title;
  final String municipality;
  final int days;
  final int stopsCount;
  final DateTime createdAt;
  final String? filter;

  const SavedItinerary({
    required this.id,
    required this.title,
    required this.municipality,
    required this.days,
    required this.stopsCount,
    required this.createdAt,
    this.filter,
  });

  factory SavedItinerary.fromJson(Map<String, dynamic> json) {
    final stops = json['stops'];
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
      stopsCount: rawStopsCount != null
          ? _asInt(rawStopsCount, fallback: 0)
          : stops is List
          ? stops.length
          : 0,
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

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    // Supporto per eventuali date Neo4j serializzate come oggetto
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
  // ── palette ──────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _primaryLight = Color(0xFFE8EFFD);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _background = Color(0xFFF9FAFB);

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
    debugPrint('SESSION userId: ${SessionService.currentUserId}');
    debugPrint('SESSION username: ${SessionService.currentUsername}');
    debugPrint('SESSION email: ${SessionService.currentEmail}');
    debugPrint('SESSION token: ${SessionService.authToken}');
    if (userId == null || userId.trim().isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Utente non loggato. Effettua il login per visualizzare i tuoi itinerari.';
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

  // ── helpers ───────────────────────────────────────────────────────────────

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
      'dic'
    ];

    return '${d.day} ${months[d.month]} ${d.year}';
  }

  Color _filterColor(String? filter) {
    if (filter == null) return Colors.transparent;

    switch (filter) {
      case 'Ho solo 2 ore':
        return const Color(0xFFFEF3C7);
      case 'Budget limitato':
        return const Color(0xFFDCFCE7);
      case 'Posti nascosti':
        return const Color(0xFFEDE9FE);
      default:
        return _primaryLight;
    }
  }

  Color _filterTextColor(String? filter) {
    if (filter == null) return Colors.transparent;

    switch (filter) {
      case 'Ho solo 2 ore':
        return const Color(0xFF92400E);
      case 'Budget limitato':
        return const Color(0xFF166534);
      case 'Posti nascosti':
        return const Color(0xFF5B21B6);
      default:
        return _primary;
    }
  }

  void _logout() {
    SessionService.logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          EasyTourHeader(
            showBack: true,
            showLogout: true,
            onLogoutTap: _logout,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMyItineraries,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primary),
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

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFFFEE2E2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 38,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Impossibile caricare gli itinerari',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: _loadMyItineraries,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Riprova'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: _primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.map_outlined,
                  color: _primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nessun itinerario salvato',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Inizia a esplorare e salva il tuo primo percorso.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: _itineraries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final itinerary = _itineraries[index];

        return _ItineraryCard(
          itinerary: itinerary,
          filterBg: _filterColor(itinerary.filter),
          filterFg: _filterTextColor(itinerary.filter),
          formattedDate: _formatDate(itinerary.createdAt),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ItineraryDetailScreen(
                  itinerary: itinerary,
                ),
              ),
            );
          },
        );
      },
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
  final String formattedDate;
  final VoidCallback onTap;

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _primaryLight = Color(0xFFE8EFFD);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);

  const _ItineraryCard({
    required this.itinerary,
    required this.filterBg,
    required this.filterFg,
    required this.formattedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.luggage_outlined,
                  color: _primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            itinerary.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: _textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: _textSecondary,
                          size: 13,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            itinerary.municipality,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: Icons.calendar_today_outlined,
                          label:
                          '${itinerary.days} ${itinerary.days == 1 ? "giorno" : "giorni"}',
                        ),
                        _MetaChip(
                          icon: Icons.place_outlined,
                          label:
                          '${itinerary.stopsCount} ${itinerary.stopsCount == 1 ? "luogo" : "luoghi"}',
                        ),
                        if (itinerary.filter != null)
                          _FilterChip(
                            label: itinerary.filter!,
                            bg: filterBg,
                            fg: filterFg,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Salvato il $formattedDate',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}