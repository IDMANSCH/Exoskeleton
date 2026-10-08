// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AccountImpl _$$AccountImplFromJson(Map<String, dynamic> json) =>
    _$AccountImpl(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      roles:
          (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
      email: json['email'] as String?,
      locale: json['locale'] as String?,
      timezone: json['timezone'] as String?,
    );

Map<String, dynamic> _$$AccountImplToJson(_$AccountImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_name': instance.displayName,
      'roles': instance.roles,
      'email': instance.email,
      'locale': instance.locale,
      'timezone': instance.timezone,
    };
