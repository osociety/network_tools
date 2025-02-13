import 'package:json_annotation/json_annotation.dart';

part 'open_port.g.dart';

/// Represents open port for a target Address
@JsonSerializable()
class OpenPort {
  OpenPort(this.port, {this.isOpen = true});
  factory OpenPort.fromJson(Map<String, dynamic> json) =>
      _$OpenPortFromJson(json);

  final int port;
  final bool isOpen;

  int compareTo(OpenPort other) {
    return port.compareTo(other.port);
  }

  @override
  int get hashCode => port.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OpenPort && other.port == port;
  }

  @override
  String toString() {
    return port.toString();
  }

  Map<String, dynamic> toJson() => _$OpenPortToJson(this);
}
