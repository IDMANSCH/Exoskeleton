import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';
part 'account.g.dart';

@freezed
class Account with _$Account {
  const factory Account({
    required String id,
    required String displayName,
    @Default(<String>[]) List<String> roles,
    String? email,
    String? locale,
    String? timezone,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);
}
