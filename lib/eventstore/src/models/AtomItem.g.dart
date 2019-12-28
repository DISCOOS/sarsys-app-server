// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AtomItem.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AtomItem _$AtomItemFromJson(Map<String, dynamic> json) {
  return AtomItem(
      id: json['id'] as String,
      title: json['title'] as String,
      updated: json['updated'] as String,
      author: json['author'] == null
          ? null
          : AtomAuthor.fromJson(json['author'] as Map<String, dynamic>),
      summary: json['summary'] as String,
      links: (json['links'] as List)
          ?.map((e) =>
              e == null ? null : AtomLink.fromJson(e as Map<String, dynamic>))
          ?.toList());
}

Map<String, dynamic> _$AtomItemToJson(AtomItem instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'updated': instance.updated,
      'summary': instance.summary,
      'author': instance.author,
      'links': instance.links
    };