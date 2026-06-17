import 'place.dart';

class ItineraryStop {
  final int ordine;
  final int giorno;
  final int tempoVisitaStimato;
  final int tempoArrivoStimato;
  final int tempoPausaStimato;
  final double? distanzaDalPuntoPrecedenteKm;
  final Place place;

  ItineraryStop({
    required this.ordine,
    required this.giorno,
    required this.tempoVisitaStimato,
    required this.tempoArrivoStimato,
    required this.place,
    this.tempoPausaStimato = 0,
    this.distanzaDalPuntoPrecedenteKm,
  });

  factory ItineraryStop.fromJson(Map<String, dynamic> json) {
    return ItineraryStop(
      ordine: _toInt(json['ordine']),
      giorno: _toInt(json['giorno']),
      tempoVisitaStimato: _toInt(json['tempoVisitaStimato']),
      tempoArrivoStimato: _toInt(json['tempoArrivoStimato']),
      tempoPausaStimato: _toInt(json['tempoPausaStimato']),
      distanzaDalPuntoPrecedenteKm:
      json['distanzaDalPuntoPrecedenteKm'] == null
          ? null
          : _toDouble(json['distanzaDalPuntoPrecedenteKm']),
      place: Place.fromJson(json['place']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ordine': ordine,
      'giorno': giorno,
      'tempoVisitaStimato': tempoVisitaStimato,
      'tempoArrivoStimato': tempoArrivoStimato,
      'tempoPausaStimato': tempoPausaStimato,
      'distanzaDalPuntoPrecedenteKm': distanzaDalPuntoPrecedenteKm,
      'place': place.toJson(),
    };
  }

  ItineraryStop copyWith({
    int? ordine,
    int? giorno,
    int? tempoVisitaStimato,
    int? tempoArrivoStimato,
    int? tempoPausaStimato,
    double? distanzaDalPuntoPrecedenteKm,
    Place? place,
  }) {
    return ItineraryStop(
      ordine: ordine ?? this.ordine,
      giorno: giorno ?? this.giorno,
      tempoVisitaStimato: tempoVisitaStimato ?? this.tempoVisitaStimato,
      tempoArrivoStimato: tempoArrivoStimato ?? this.tempoArrivoStimato,
      tempoPausaStimato: tempoPausaStimato ?? this.tempoPausaStimato,
      distanzaDalPuntoPrecedenteKm:
      distanzaDalPuntoPrecedenteKm ?? this.distanzaDalPuntoPrecedenteKm,
      place: place ?? this.place,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();

    if (value is Map && value.containsKey('low')) {
      return value['low'] as int;
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();

    if (value is Map && value.containsKey('low')) {
      return (value['low'] as int).toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }
}