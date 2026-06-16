/*
  Modello utente EasyTour.
  Rispecchia il campo "user" restituito dal backend in fase di
  login e registrazione (/auth/login, /auth/register/...).

  Il campo municipalityId è valorizzato solo per gli operatori
  comunali (serve alla dashboard per sapere quale Comune mostrare).
*/
class User {
  final String id;
  final String nome;
  final String email;
  final String ruolo; // "TURISTA" oppure "OPERATORE_COMUNALE"
  final String? municipalityId;

  const User({
    required this.id,
    required this.nome,
    required this.email,
    required this.ruolo,
    this.municipalityId,
  });

  bool get isOperatore => ruolo == 'OPERATORE_COMUNALE';
  bool get isTurista => ruolo == 'TURISTA';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      ruolo: json['ruolo']?.toString() ?? '',
      municipalityId: json['municipalityId']?.toString(),
    );
  }
}

/*
  Risultato di un'operazione di autenticazione:
  contiene sia il token JWT sia i dati dell'utente.
*/
class AuthResult {
  final String token;
  final User user;

  const AuthResult({
    required this.token,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token']?.toString() ?? '',
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
