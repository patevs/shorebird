#!/bin/bash

# This script outputs an artifact_manifest.yaml mapping 
# a shorebird engine revision to a flutter engine revision.
# Usage:
#  ./generate_manifest.sh <flutter_engine_revision> > artifact_manifest.yaml

set -e

# NOTE: If you edit this file you also may need to edit the global list
# of all known artifacts in config.dart

if [ "$#" -ne 1 ]; then
  echo "Usage: ./generate_manifest.sh <flutter_engine_revision>"
  exit 1
fi

FLUTTER_ENGINE_REVISION=$1

cat <<EOF
# This file is generated by shorebird/packages/artifact_proxy/tool/generate_manifest.sh
# Do not edit this file manually.

flutter_engine_revision: $FLUTTER_ENGINE_REVISION
storage_bucket: download.shorebird.dev
artifact_overrides:
  # Android release artifacts
  # artifacts.zip includes flutter.jar, libflutter.so, etc.
  # symbols.zip includes symbols for libflutter.so
  # darwin-x64.zip gen_snapshot for darwin-x64
  # windows-x64.zip gen_snapshot for windows-x64
  # linux-x64.zip gen_snapshot for linux-x64
  - flutter_infra_release/flutter/\$engine/android-arm64-release/artifacts.zip
  - flutter_infra_release/flutter/\$engine/android-arm64-release/darwin-x64.zip
  - flutter_infra_release/flutter/\$engine/android-arm64-release/linux-x64.zip
  - flutter_infra_release/flutter/\$engine/android-arm64-release/symbols.zip
  - flutter_infra_release/flutter/\$engine/android-arm64-release/windows-x64.zip

  - flutter_infra_release/flutter/\$engine/android-arm-release/artifacts.zip
  - flutter_infra_release/flutter/\$engine/android-arm-release/darwin-x64.zip
  - flutter_infra_release/flutter/\$engine/android-arm-release/linux-x64.zip
  - flutter_infra_release/flutter/\$engine/android-arm-release/symbols.zip
  - flutter_infra_release/flutter/\$engine/android-arm-release/windows-x64.zip

  - flutter_infra_release/flutter/\$engine/android-x64-release/artifacts.zip
  - flutter_infra_release/flutter/\$engine/android-x64-release/darwin-x64.zip
  - flutter_infra_release/flutter/\$engine/android-x64-release/linux-x64.zip
  - flutter_infra_release/flutter/\$engine/android-x64-release/symbols.zip
  - flutter_infra_release/flutter/\$engine/android-x64-release/windows-x64.zip

  # Dart SDK
  - flutter_infra_release/flutter/\$engine/dart-sdk-darwin-arm64.zip
  - flutter_infra_release/flutter/\$engine/dart-sdk-darwin-x64.zip
  - flutter_infra_release/flutter/\$engine/dart-sdk-linux-x64.zip
  - flutter_infra_release/flutter/\$engine/dart-sdk-windows-x64.zip

  # embedding release
  - download.flutter.io/io/flutter/flutter_embedding_release/1.0.0-\$engine/flutter_embedding_release-1.0.0-\$engine.pom
  - download.flutter.io/io/flutter/flutter_embedding_release/1.0.0-\$engine/flutter_embedding_release-1.0.0-\$engine.jar
  # arm64_v8a release
  - download.flutter.io/io/flutter/arm64_v8a_release/1.0.0-\$engine/arm64_v8a_release-1.0.0-\$engine.pom
  - download.flutter.io/io/flutter/arm64_v8a_release/1.0.0-\$engine/arm64_v8a_release-1.0.0-\$engine.jar
  # armeabi_v7a release
  - download.flutter.io/io/flutter/armeabi_v7a_release/1.0.0-\$engine/armeabi_v7a_release-1.0.0-\$engine.pom
  - download.flutter.io/io/flutter/armeabi_v7a_release/1.0.0-\$engine/armeabi_v7a_release-1.0.0-\$engine.jar
  # x86_64 release
  - download.flutter.io/io/flutter/x86_64_release/1.0.0-\$engine/x86_64_release-1.0.0-\$engine.pom
  - download.flutter.io/io/flutter/x86_64_release/1.0.0-\$engine/x86_64_release-1.0.0-\$engine.jar

  # Common release artifacts
  - flutter_infra_release/flutter/\$engine/flutter_patched_sdk_product.zip

  # iOS release artifacts
  # Includes unified Flutter.framework for device and simulator (debug)
  - flutter_infra_release/flutter/\$engine/ios-release/artifacts.zip
  - flutter_infra_release/flutter/\$engine/ios-release/Flutter.dSYM.zip

  # Linux release artifacts
  - flutter_infra_release/flutter/\$engine/linux-x64/artifacts.zip
  - flutter_infra_release/flutter/\$engine/linux-x64-release/linux-x64-flutter-gtk.zip

  # macOS release artifacts
  - flutter_infra_release/flutter/\$engine/darwin-x64-release/artifacts.zip
  - flutter_infra_release/flutter/\$engine/darwin-x64-release/framework.zip
  - flutter_infra_release/flutter/\$engine/darwin-x64-release/gen_snapshot.zip

  # Windows release artifacts
  - flutter_infra_release/flutter/\$engine/windows-x64/artifacts.zip
  - flutter_infra_release/flutter/\$engine/windows-x64-release/windows-x64-flutter.zip
