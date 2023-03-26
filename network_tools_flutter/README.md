# Features

This package will add support for flutter only features in network_tools, network_tools will still be required to be added in pubspec.yaml.  

## Getting started

```dart
import 'package:network_tools_flutter/network_tools.dart';

```

## Usage

```dart
main() {
    NetworkToolsFlutter.init();
}
```

## Additional information

Currently getAllPingableDevicesAsync() is not working on ios because of plugin registration
