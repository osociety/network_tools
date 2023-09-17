// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arp_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARPData _$ARPDataFromJson(Map<String, dynamic> json) => ARPData(
      host: json['host'] as String?,
      iPAddress: json['iPAddress'] as String?,
      macAddress: json['macAddress'] as String?,
      interfaceName: json['interfaceName'] as String?,
      interfaceType: json['interfaceType'] as String?,
    );

Map<String, dynamic> _$ARPDataToJson(ARPData instance) => <String, dynamic>{
      'host': instance.host,
      'iPAddress': instance.iPAddress,
      'macAddress': instance.macAddress,
      'interfaceName': instance.interfaceName,
      'interfaceType': instance.interfaceType,
    };
