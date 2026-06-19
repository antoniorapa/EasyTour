import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import '../widgets/easytour_header.dart';

class DashboardPage extends StatefulWidget {
  final User user;
  final String token;

  const DashboardPage({super.key, required this.user, required this.token});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService apiService = ApiService();

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF4F7FA);

  bool isLoading = true;
  bool _topPlacesExpanded = false;
  bool _improveExpanded = false;
  String? errorMessage;

  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> topPlaces = [];
  List<Map<String, dynamic>> placesToImprove = [];
  List<Map<String, dynamic>> filters = [];
  List<Map<String, dynamic>> reports = [];

  // Cache delle immagini recuperate per nome luogo (evita richieste ripetute).
  final Map<String, Future<String?>> _imageCache = {};

  // Recupera l'immagine di un luogo. Se immagineUrl è valido lo usa,
  // altrimenti (vuoto o URL finto example.com) prova Wikipedia.
  Future<String?> _getPlaceImage(Map<String, dynamic> place) {
    final nome = place['nome']?.toString() ?? '';
    final url = place['immagineUrl']?.toString() ?? '';

    final cacheKey = nome.isNotEmpty ? nome : url;
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    final future = _fetchPlaceImage(nome, url);
    _imageCache[cacheKey] = future;
    return future;
  }

  Future<String?> _fetchPlaceImage(String nome, String url) async {
    // URL valido e non finto -> usalo direttamente.
    final isFake = url.contains('example.com');
    if (url.isNotEmpty && !isFake) {
      return url;
    }

    if (nome.isEmpty) return null;

    // Prova il summary di Wikipedia (di solito ha l'immagine principale).
    try {
      final summary = await apiService.getWikipediaSummary(nome);
      final wikiUrl = summary['immagineUrl']?.toString();
      if (wikiUrl != null && wikiUrl.isNotEmpty) return wikiUrl;
    } catch (_) {}

    // Fallback: prima immagine dalla lista Wikipedia.
    try {
      final images = await apiService.getWikipediaImages(nome);
      if (images.isNotEmpty && images.first.isNotEmpty) return images.first;
    } catch (_) {}

    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? _buildError()
                : RefreshIndicator(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(errorMessage ?? 'Errore',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
              child: const Text('Riprova',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- Barra in alto con logo e logout ---
  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.location_on, color: orange, size: 28),
            const SizedBox(width: 6),
            const Text(
              'EasyTour',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryBlue,
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: primaryBlue),
          onPressed: _logout,
          tooltip: 'Esci',
        ),
      ],
    );
  }

  // --- Titolo + selettore Comune ---
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
                'Analisi degli itinerari e feedback dei cittadini',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
              Icon(Icons.location_on, size: 18, color: primaryBlue),
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

  String _nomeComune() {
    final id = widget.user.municipalityId ?? '';
    if (id.isEmpty) return 'Comune';
    // "comune_salerno" -> "Salerno"
    final parte = id.replaceFirst('comune_', '');
    return parte.isEmpty
        ? 'Comune'
        : parte[0].toUpperCase() + parte.substring(1);
  }

  // --- 4 card statistiche ---
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

  Widget _statCard(_StatData d) {
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
              color: d.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(d.icon, color: d.iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            d.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          Text(
            d.label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // --- Sezione luoghi (più presenti + da valorizzare) ---
  Widget _buildPlacesSection() {
    // Quanti elementi mostrare in base allo stato espanso.
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
                      (i) => _topPlaceRow(i + 1, topPlaces[i]),
                    ),
                    if (topPlaces.length > 3)
                      _vediTuttiToggle(
                        expanded: _topPlacesExpanded,
                        onTap: () => setState(
                            () => _topPlacesExpanded = !_topPlacesExpanded),
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
                      (i) => _improveRow(placesToImprove[i]),
                    ),
                    if (placesToImprove.length > 3)
                      _vediTuttiToggle(
                        expanded: _improveExpanded,
                        onTap: () => setState(
                            () => _improveExpanded = !_improveExpanded),
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
            Text(expanded ? 'Vedi meno' : 'Vedi tutti',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 2),
            Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
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
            child: Text('$rank',
                style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
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
                style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              Text('presenze',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
                Text('${place['presenze'] ?? 0} presenze',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image, color: Colors.grey),
            );
          },
        ),
      ),
    );
  }

  // --- Grafico a barre filtri ---
  Widget _buildFiltersSection() {
    return _card(
      title: 'Filtri più usati negli itinerari',
      child: filters.isEmpty
          ? _emptyHint('Nessun filtro registrato')
          : _barChart(),
    );
  }

  Widget _barChart() {
    final maxVal = filters
        .map((f) => (f['quanti'] ?? 0) as int)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return Column(
      children: filters.map((f) {
        final val = (f['quanti'] ?? 0) as int;
        final frazione = val / maxVal;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              // Etichetta a sinistra, più stretta -> la barra parte prima.
              SizedBox(
                width: 80,
                child: Text(
                  f['filtro']?.toString() ?? '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fullWidth = constraints.maxWidth;
                    final barWidth = (fullWidth * frazione).clamp(0.0, fullWidth);
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Binario di sfondo sottile.
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF1F5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        // Se 0 -> pallino blu all'inizio; altrimenti barra che cresce.
                        if (val == 0)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          Container(
                            height: 10,
                            width: barWidth,
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
                width: 26,
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

  // --- Segnalazioni (placeholder) ---
  Widget _buildReportsSection() {
    return _card(
      title: 'Segnalazioni recenti',
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
              children: reports
                  .take(3)
                  .map((r) => ListTile(
                        leading: const Icon(Icons.campaign,
                            color: Color(0xFFE0556E)),
                        title: Text(r['categoria']?.toString() ?? 'Segnalazione'),
                        subtitle: Text(r['descrizione']?.toString() ?? ''),
                      ))
                  .toList(),
            ),
    );
  }

  // --- Helper card generica ---
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
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
      child: Text(text, style: TextStyle(color: Colors.grey[500])),
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
