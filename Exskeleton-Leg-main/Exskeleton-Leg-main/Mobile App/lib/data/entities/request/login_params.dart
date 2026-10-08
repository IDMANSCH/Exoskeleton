class LoginParams {
  final String email;
  final String password;
  final String? deviceLabel;

  const LoginParams({
    required this.email,
    required this.password,
    this.deviceLabel,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    if (deviceLabel != null) 'device_label': deviceLabel,
  };
}
