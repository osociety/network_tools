// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_port.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpenPort _$OpenPortFromJson(Map<String, dynamic> json) => OpenPort(
  (json['port'] as num).toInt(),
  isOpen: json['isOpen'] as bool? ?? true,
);

Map<String, dynamic> _$OpenPortToJson(OpenPort instance) => <String, dynamic>{
  'port': instance.port,
  'isOpen': instance.isOpen,
};
