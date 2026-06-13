class Place {
  final String id;
  final String? googlePlaceId;

  final String? photoReference;
  final String nome;
  final double latitudine;
  final double longitudine;

  final double rating;
  final int numeroRecensioni;

  final String descrizione;
  final String immagineUrl;
  final String categoria;

  final double? distanzaKm;

  final String? comune;
  final String? indirizzo;
  final String? photoName;
  final String? source;

  Place({
    required this.id,
    this.googlePlaceId,
    required this.nome,
    required this.latitudine,
    required this.longitudine,
    required this.rating,
    required this.numeroRecensioni,
    required this.descrizione,
    required this.immagineUrl,
    required this.categoria,
    this.distanzaKm,
    this.comune,
    this.indirizzo,
    this.photoName,
    this.source,
    this.photoReference,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id']?.toString() ?? '',
      googlePlaceId: json['googlePlaceId']?.toString(),
      nome: json['nome']?.toString() ?? '',
      latitudine: _toDouble(json['latitudine']),
      longitudine: _toDouble(json['longitudine']),
      rating: _toDouble(json['rating']),
      numeroRecensioni: _toInt(json['numeroRecensioni']),
      descrizione: json['descrizione']?.toString() ?? '',
      immagineUrl: json['immagineUrl']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? '',
      photoReference: json['photoReference']?.toString(),
      distanzaKm:
      json['distanzaKm'] == null ? null : _toDouble(json['distanzaKm']),
      comune: json['comune']?.toString(),
      indirizzo: json['indirizzo']?.toString(),
      photoName: json['photoName']?.toString(),
      source: json['source']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'googlePlaceId': googlePlaceId,
      'nome': nome,
      'latitudine': latitudine,
      'longitudine': longitudine,
      'rating': rating,
      'numeroRecensioni': numeroRecensioni,
      'descrizione': descrizione,
      'immagineUrl': immagineUrl,
      'categoria': categoria,
      'distanzaKm': distanzaKm,
      'comune': comune,
      'indirizzo': indirizzo,
      'photoName': photoName,
      'source': source,
      'photoReference': photoReference,
    };
  }

  Place copyWith({
    String? id,
    String? googlePlaceId,
    String? nome,
    String? photoReference,
    double? latitudine,
    double? longitudine,
    double? rating,
    int? numeroRecensioni,
    String? descrizione,
    String? immagineUrl,
    String? categoria,
    double? distanzaKm,
    String? comune,
    String? indirizzo,
    String? photoName,
    String? source,
  }) {
    return Place(
      id: id ?? this.id,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      photoReference: photoReference ?? this.photoReference,
      nome: nome ?? this.nome,
      latitudine: latitudine ?? this.latitudine,
      longitudine: longitudine ?? this.longitudine,
      rating: rating ?? this.rating,
      numeroRecensioni: numeroRecensioni ?? this.numeroRecensioni,
      descrizione: descrizione ?? this.descrizione,
      immagineUrl: immagineUrl ?? this.immagineUrl,
      categoria: categoria ?? this.categoria,
      distanzaKm: distanzaKm ?? this.distanzaKm,
      comune: comune ?? this.comune,
      indirizzo: indirizzo ?? this.indirizzo,
      photoName: photoName ?? this.photoName,
      source: source ?? this.source,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;
    if (value is int) return value.toDouble();

    if (value is Map && value.containsKey('low')) {
      final low = value['low'];
      if (low is int) return low.toDouble();
      if (low is double) return low;
      return double.tryParse(low.toString()) ?? 0.0;
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;
    if (value is double) return value.toInt();

    if (value is Map && value.containsKey('low')) {
      final low = value['low'];
      if (low is int) return low;
      if (low is double) return low.toInt();
      return int.tryParse(low.toString()) ?? 0;
    }

    return int.tryParse(value.toString()) ?? 0;
  }
}