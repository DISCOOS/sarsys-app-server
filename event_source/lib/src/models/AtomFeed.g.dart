// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AtomFeed.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AtomFeed _$AtomFeedFromJson(Map json) {
  return AtomFeed(
      id: json['id'] as String,
      title: json['title'] as String,
      updated: json['updated'] as String,
      author: json['author'] == null
          ? null
          : AtomAuthor.fromJson((json['author'] as Map)?.map(
              (k, e) => MapEntry(k as String, e),
            )),
      streamId: json['streamId'] as String,
      headOfStream: json['headOfStream'] as bool,
      selfUrl: json['selfUrl'] as String,
      eTag: json['eTag'] as String,
      links: (json['links'] as List)
          ?.map((e) => e == null
              ? null
              : AtomLink.fromJson((e as Map)?.map(
                  (k, e) => MapEntry(k as String, e),
                )))
          ?.toList(),
      entries: (json['entries'] as List)
          ?.map((e) => e == null
              ? null
              : AtomItem.fromJson((e as Map)?.map(
                  (k, e) => MapEntry(k as String, e),
                )))
          ?.toList());
}

Map<String, dynamic> _$AtomFeedToJson(AtomFeed instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'updated': instance.updated,
      'streamId': instance.streamId,
      'author': instance.author?.toJson(),
      'headOfStream': instance.headOfStream,
      'selfUrl': instance.selfUrl,
      'eTag': instance.eTag,
      'links': instance.links?.map((e) => e?.toJson())?.toList(),
      'entries': instance.entries?.map((e) => e?.toJson())?.toList()
    };
