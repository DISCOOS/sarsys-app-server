// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SourceModel _$SourceModelFromJson(Map<String, dynamic> json) {
  return SourceModel(uuid: json['uuid'] as String, type: _$enumDecodeNullable(_$SourceTypeEnumMap, json['type']));
}

Map<String, dynamic> _$SourceModelToJson(SourceModel instance) =>
    <String, dynamic>{'uuid': instance.uuid, 'type': _$SourceTypeEnumMap[instance.type]};

T _$enumDecode<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }
  return enumValues.entries
      .singleWhere((e) => e.value == source,
          orElse: () => throw ArgumentError('`$source` is not one of the supported values: '
              '${enumValues.values.join(', ')}'))
      .key;
}

T _$enumDecodeNullable<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source);
}

const _$SourceTypeEnumMap = <SourceType, dynamic>{SourceType.device: 'device', SourceType.trackable: 'trackable'};
