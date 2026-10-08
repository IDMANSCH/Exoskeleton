class RegisterParams {
  final String email;
  final String password;
  final String displayName;
  final String locale;
  final String timezone;
  final String acceptedTermsVersion;
  final String? deviceLabel;
  final String role;

  const RegisterParams({
    required this.email,
    required this.password,
    required this.displayName,
    this.locale = 'vi',
    this.timezone = 'Asia/Ho_Chi_Minh',
    this.acceptedTermsVersion = '2026-01',
    this.deviceLabel,
    this.role = 'patient',
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'display_name': displayName,
    'locale': locale,
    'timezone': timezone,
    'accepted_terms_version': acceptedTermsVersion,
    if (deviceLabel != null) 'device_label': deviceLabel,
    'role': role,
  };
}
