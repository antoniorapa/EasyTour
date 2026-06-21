import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import '../widgets/easytour_header.dart';

class DashboardPage extends StatefulWidget {
  final User user;
  final String token;

  const DashboardPage({
    super.key,
    required this.user,
    required this.token,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService apiService = ApiService();

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF4F7FA);
  static const Color green = Color(0xFF00A676);
  static const Color dangerRed = Color(0xFFE53935);

  bool isLoading = true;
  bool _topPlacesExpanded = false;
  bool _improveExpanded = false;
  bool _reportsExpanded = false;

  String? errorMessage;

  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> topPlaces = [];
  List<Map<String, dynamic>> placesToImprove = [];
  List<Map<String, dynamic>> filters = [];
  List<Map<String, dynamic>> reports = [];

  final Map<String, Future<String?>> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String?> _getPlaceImage(Map<String, dynamic> place) {
    final nome = place['nome']?.toString() ??
        place['placeName']?.toString() ??
        place['luogo']?.toString() ??
        '';

    final url = place['immagineUrl']?.toString() ??
        place['imageUrl']?.toString() ??
        '';

    final cacheKey = nome.isNotEmpty ? nome : url;

    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    final future = _fetchPlaceImage(nome, url);
    _imageCache[cacheKey] = future;

    return future;
  }

  Future<String?> _fetchPlaceImage(String nome, String url) async {
    final isFake = url.contains('example.com');

    if (url.isNotEmpty && !isFake) {
      return url;
    }

    if (nome.isEmpty) return null;

    try {
      final summary = await apiService.getWikipediaSummary(nome);

      final wikiUrl = summary['immagineUrl']?.toString() ??
          summary['imageUrl']?.toString() ??
          summary['thumbnail']?['source']?.toString() ??
          summary['originalimage']?['source']?.toString();

      if (wikiUrl != null && wikiUrl.isNotEmpty) {
        return wikiUrl;
      }
    } catch (_) {}

    try {
      final images = await apiService.getWikipediaImages(nome);

      if (images.isNotEmpty && images.first.isNotEmpty) {
        return images.first;
      }
    } catch (_) {}

    return null;
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        apiService.getDashboardSummary(widget.token),
        apiService.getTopPlaces(widget.token),
        apiService.getPlacesToImprove(widget.token),
        apiService.getDashboardFilters(widget.token),
        apiService.getDashboardReports(widget.token),
      ]);

      if (!mounted) return;

      setState(() {
        summary = results[0] as Map<String, dynamic>;
        topPlaces = results[1] as List<Map<String, dynamic>>;
        placesToImprove = results[2] as List<Map<String, dynamic>>;
        filters = results[3] as List<Map<String, dynamic>>;
        reports = results[4] as List<Map<String, dynamic>>;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  String _nomeComune() {
    final id = widget.user.municipalityId ?? '';

    if (id.isEmpty) return 'Comune';

    final parte = id.replaceFirst('comune_', '').replaceAll('_', ' ');

    if (parte.isEmpty) return 'Comune';

    return parte
        .split(' ')
        .map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    })
        .join(' ');
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();

    if (value is Map) {
      final low = value['low'];

      if (low is int) return low;
      if (low is double) return low.toInt();

      return int.tryParse(low?.toString() ?? '') ?? 0;
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;

    final text = value.toString();

    if (text.trim().isEmpty) return fallback;

    return text;
  }

  String _filterLabelFromRaw(dynamic value) {
    final raw = value?.toString().trim() ?? '';

    if (raw.isEmpty) return 'Tutti';

    final lower = raw.toLowerCase();

    if (lower == 'none' || lower == 'tutti') {
      return 'Tutti';
    }

    if (lower == 'ho_solo_2_ore' ||
        lower == '2 ore' ||
        lower == 'ho solo 2 ore' ||
        lower == 'solo 2 ore') {
      return 'Ho solo 2 ore';
    }

    if (lower == 'budget_limitato' ||
        lower == 'budget limitato' ||
        lower == 'budget') {
      return 'Budget limitato';
    }

    if (lower == 'posti_nascosti' ||
        lower == 'posti nascosti' ||
        lower == 'nascosti' ||
        lower == 'hidden gems') {
      return 'Posti nascosti';
    }

    return raw;
  }

  List<Map<String, dynamic>> _normalizedFilters() {
    final Map<String, int> counts = {
      'Tutti': 0,
      'Ho solo 2 ore': 0,
      'Budget limitato': 0,
      'Posti nascosti': 0,
    };

    for (final filter in filters) {
      final label = _filterLabelFromRaw(
        filter['filtro'] ?? filter['filterType'] ?? filter['label'],
      );

      final quanti = _asInt(
        filter['quanti'] ?? filter['count'] ?? filter['totale'],
      );

      counts[label] = (counts[label] ?? 0) + quanti;
    }

    return counts.entries
        .map((entry) => {
      'filtro': entry.key,
      'quanti': entry.value,
    })
        .toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    final text = value.toString();

    if (text.isEmpty) return '';

    final parsed = DateTime.tryParse(text);

    if (parsed == null) {
      return text.length > 16 ? text.substring(0, 16) : text;
    }

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year} '
        '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String stato) {
    switch (stato.toUpperCase()) {
      case 'RISOLTA':
      case 'RISOLTO':
      case 'CHIUSA':
      case 'CHIUSO':
        return green;
      case 'IN_LAVORAZIONE':
      case 'IN LAVORAZIONE':
        return orange;
      case 'NUOVA':
      default:
        return dangerRed;
    }
  }

  String _statusLabel(String stato) {
    if (stato.trim().isEmpty) return 'Nuova';

    switch (stato.toUpperCase()) {
      case 'IN_LAVORAZIONE':
        return 'In lavorazione';
      case 'RISOLTA':
        return 'Risolta';
      case 'CHIUSA':
        return 'Chiusa';
      case 'NUOVA':
        return 'Nuova';
      default:
        return stato;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: SafeArea(
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(color: primaryBlue),
        )
            : errorMessage != null
            ? _buildError()
            : RefreshIndicator(
          color: primaryBlue,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EasyTourHeader(
                  showLogout: true,
                  onLogoutTap: _logout,
                ),
                const SizedBox(height: 20),
                _buildTitle(),
                const SizedBox(height: 16),
                _buildStatCards(),
                const SizedBox(height: 20),
                _buildPlacesSection(),
                const SizedBox(height: 20),
                _buildFiltersSection(),
                const SizedBox(height: 20),
                _buildReportsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage ?? 'Errore',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard Comune',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Analisi degli itinerari, luoghi e segnalazioni utenti',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 18,
                color: primaryBlue,
              ),
              const SizedBox(width: 4),
              Text(
                _nomeComune(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    final cards = [
      _StatData(
        icon: Icons.bookmark,
        iconColor: primaryBlue,
        bg: const Color(0xFFE3EEF6),
        value: '${summary['itinerariSalvati'] ?? 0}',
        label: 'Itinerari salvati',
      ),
      _StatData(
        icon: Icons.account_balance,
        iconColor: const Color(0xFF2E9E8F),
        bg: const Color(0xFFDFF3EF),
        value: '${summary['luoghiPiuPresenti'] ?? 0}',
        label: 'Luoghi più presenti',
      ),
      _StatData(
        icon: Icons.star,
        iconColor: orange,
        bg: const Color(0xFFFDEFD9),
        value: '${placesToImprove.length}',
        label: 'Hidden gems',
      ),
      _StatData(
        icon: Icons.campaign,
        iconColor: const Color(0xFFE0556E),
        bg: const Color(0xFFFBE2E8),
        value: '${reports.length}',
        label: 'Segnalazioni',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: cards.map(_statCard).toList(),
    );
  }

  Widget _statCard(_StatData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              data.icon,
              color: data.iconColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesSection() {
    final topCount = _topPlacesExpanded
        ? topPlaces.length
        : (topPlaces.length > 3 ? 3 : topPlaces.length);

    final improveCount = _improveExpanded
        ? placesToImprove.length
        : (placesToImprove.length > 3 ? 3 : placesToImprove.length);

    return Column(
      children: [
        _card(
          title: 'Luoghi più presenti negli itinerari',
          child: topPlaces.isEmpty
              ? _emptyHint('Nessun itinerario salvato')
              : Column(
            children: [
              ...List.generate(
                topCount,
                    (index) => _topPlaceRow(index + 1, topPlaces[index]),
              ),
              if (topPlaces.length > 3)
                _vediTuttiToggle(
                  expanded: _topPlacesExpanded,
                  onTap: () {
                    setState(() {
                      _topPlacesExpanded = !_topPlacesExpanded;
                    });
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          title: 'Luoghi da valorizzare',
          subtitle: 'Poche presenze, alto gradimento',
          child: placesToImprove.isEmpty
              ? _emptyHint('Nessun dato disponibile')
              : Column(
            children: [
              ...List.generate(
                improveCount,
                    (index) => _improveRow(placesToImprove[index]),
              ),
              if (placesToImprove.length > 3)
                _vediTuttiToggle(
                  expanded: _improveExpanded,
                  onTap: () {
                    setState(() {
                      _improveExpanded = !_improveExpanded;
                    });
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vediTuttiToggle({
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              expanded ? 'Vedi meno' : 'Vedi tutti',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _topPlaceRow(int rank, Map<String, dynamic> place) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFE3EEF6),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _placeThumb(place),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              place['nome']?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${place['presenze'] ?? 0}',
                style: const TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'presenze',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _improveRow(Map<String, dynamic> place) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _placeThumb(place),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place['nome']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${place['presenze'] ?? 0} presenze',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFF5B301), size: 16),
              const SizedBox(width: 2),
              Text(
                '${place['rating'] ?? '-'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeThumb(Map<String, dynamic> place) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        color: Colors.grey.shade200,
        child: FutureBuilder<String?>(
          future: _getPlaceImage(place),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final url = snapshot.data;

            if (url == null || url.isEmpty) {
              return const Icon(Icons.place, color: Colors.grey);
            }

            return Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(Icons.image, color: Colors.grey);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    final normalizedFilters = _normalizedFilters();

    return _card(
      title: 'Filtri più usati negli itinerari',
      child: normalizedFilters.isEmpty
          ? _emptyHint('Nessun filtro registrato')
          : _barChart(normalizedFilters),
    );
  }

  Widget _barChart(List<Map<String, dynamic>> normalizedFilters) {
    final maxVal = normalizedFilters
        .map((filter) => _asInt(filter['quanti']))
        .fold<int>(1, (a, b) => a > b ? a : b);

    return Column(
      children: normalizedFilters.map((filter) {
        final label = filter['filtro']?.toString() ?? '-';
        final val = _asInt(filter['quanti']);
        final fraction = val / maxVal;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 95,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fullWidth = constraints.maxWidth;
                    final barWidth = (fullWidth * fraction).clamp(
                      0.0,
                      fullWidth,
                    );

                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF1F5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        if (val == 0)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: primaryBlue.withOpacity(0.45),
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          Container(
                            height: 10,
                            width: barWidth < 14 ? 14 : barWidth,
                            decoration: BoxDecoration(
                              color: primaryBlue,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  '$val',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReportsSection() {
    final visibleReports = _reportsExpanded ? reports : reports.take(3).toList();

    return _card(
      title: 'Segnalazioni recenti',
      subtitle: 'Report inviati dagli utenti al Comune di ${_nomeComune()}',
      child: reports.isEmpty
          ? Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.inbox, color: Colors.grey[400]),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nessuna segnalazione ricevuta.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          ...visibleReports.map(_reportCard),
          if (reports.length > 3)
            _vediTuttiToggle(
              expanded: _reportsExpanded,
              onTap: () {
                setState(() {
                  _reportsExpanded = !_reportsExpanded;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final categoria = _asString(
      report['categoria'] ?? report['category'],
      fallback: 'Segnalazione',
    );

    final descrizione = _asString(
      report['descrizione'] ?? report['description'],
      fallback: 'Nessuna descrizione disponibile.',
    );

    final stato = _asString(
      report['stato'] ?? report['status'],
      fallback: 'NUOVA',
    );

    final placeName = _asString(
      report['placeName'] ??
          report['luogo'] ??
          report['nomeLuogo'] ??
          report['place'],
      fallback: 'Luogo non specificato',
    );

    final username = _asString(
      report['username'] ?? report['userEmail'] ?? report['userId'],
      fallback: 'Utente',
    );

    final dataCreazione = _formatDate(
      report['dataCreazione'] ?? report['createdAt'] ?? report['date'],
    );

    final statusColor = _statusColor(stato);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3D7DD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFBE2E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Color(0xFFE0556E),
              size: 24,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        categoria,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: darkBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusLabel(stato),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  descrizione,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _reportInfoChip(
                      icon: Icons.place_rounded,
                      text: placeName,
                      color: primaryBlue,
                    ),
                    _reportInfoChip(
                      icon: Icons.person_rounded,
                      text: username,
                      color: orange,
                    ),
                    if (dataCreazione.isNotEmpty)
                      _reportInfoChip(
                        icon: Icons.schedule_rounded,
                        text: dataCreazione,
                        color: green,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportInfoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey[500]),
      ),
    );
  }
}

class _StatData {
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final String value;
  final String label;

  _StatData({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.value,
    required this.label,
  });
}