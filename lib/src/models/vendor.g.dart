// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Vendor _$VendorFromJson(Map<String, dynamic> json) => Vendor(
  macPrefix: json['macPrefix'] as String,
  vendorName: json['vendorName'] as String,
  private: json['private'] as String,
  blockType: json['blockType'] as String,
  lastUpdate: json['lastUpdate'] as String,
);

Map<String, dynamic> _$VendorToJson(Vendor instance) => <String, dynamic>{
  'macPrefix': instance.macPrefix,
  'vendorName': instance.vendorName,
  'private': instance.private,
  'blockType': instance.blockType,
  'lastUpdate': instance.lastUpdate,
};
