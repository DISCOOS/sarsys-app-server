import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:sarsys_domain/src/core/models/coordinates.dart';
import 'package:sarsys_domain/src/core/models/point.dart';
import 'package:sarsys_domain/src/core/models/source.dart';

part 'position.g.dart';

@JsonSerializable(explicitToJson: true)
class PositionModel extends Equatable {
  PositionModel({
    @required this.geometry,
    @required this.properties,
  }) : super();

  final PointModel geometry;
  final PositionModelProps properties;
  final String type = 'Feature';

  @JsonKey(ignore: true)
  double get lat => geometry.lat;

  @JsonKey(ignore: true)
  double get lon => geometry.lon;

  @JsonKey(ignore: true)
  double get alt => geometry.alt;

  @JsonKey(ignore: true)
  double get acc => properties.acc;

  @JsonKey(ignore: true)
  SourceType get source => properties.source;

  @JsonKey(ignore: true)
  DateTime get timestamp => properties.timestamp;

  @override
  List<Object> get props => [
        geometry,
        properties,
        type,
      ];

  bool get isEmpty => geometry.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Factory constructor for [PositionModel]
  factory PositionModel.from({
    @required double lat,
    @required double lon,
    @required SourceType source,
    @required DateTime timestamp,
    double acc,
    double alt,
  }) =>
      PositionModel(
        geometry: PointModel(
          coordinates: CoordinatesModel(
            lat: lat,
            lon: lon,
            alt: alt,
          ),
        ),
        properties: PositionModelProps(
          acc: acc,
          source: source,
          timestamp: timestamp ?? DateTime.now(),
        ),
      );

  /// Factory constructor for creating a new `Point`  instance
  factory PositionModel.fromJson(Map<String, dynamic> json) => _$PositionModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PositionModelToJson(this);
}

@JsonSerializable(explicitToJson: true)
class PositionModelProps extends Equatable {
  @JsonKey(name: 'accuracy')
  final double acc;
  final DateTime timestamp;
  final SourceType source;

  PositionModelProps({
    @required this.acc,
    @required this.timestamp,
    this.source = SourceType.manual,
  }) : super();

  @override
  List<Object> get props => [
        acc,
        timestamp,
        source,
      ];

  /// Factory constructor for creating a new `Point`  instance
  factory PositionModelProps.fromJson(Map<String, dynamic> json) => _$PositionModelPropsFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PositionModelPropsToJson(this);
}
