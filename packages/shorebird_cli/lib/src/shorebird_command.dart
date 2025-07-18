import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:shorebird_cli/src/shorebird_cli_command_runner.dart';
import 'package:shorebird_code_push_client/shorebird_code_push_client.dart';

/// Signature for a function which takes a list of bytes and returns a hash.
typedef HashFunction = String Function(List<int> bytes);

/// Signature for a function which takes a path to a zip file.
typedef UnzipFn = Future<void> Function(String zipFilePath, String outputDir);

/// Signature for a function which builds a [CodePushClient].
typedef CodePushClientBuilder =
    CodePushClient Function({required http.Client httpClient, Uri? hostedUri});

/// Signature for a function which starts a process (e.g. [Process.start]).
typedef StartProcess =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      bool runInShell,
    });

/// {@template shorebird_command}
/// A command in the Shorebird CLI.
/// {@endtemplate}
abstract class ShorebirdCommand extends Command<int> {
  // We don't currently have a test involving both a CommandRunner
  // and a Command, so we can't test this getter.
  // coverage:ignore-start
  @override
  ShorebirdCliCommandRunner? get runner =>
      testRunner ?? super.runner as ShorebirdCliCommandRunner?;
  // coverage:ignore-end

  /// [ArgResults] used for testing purposes only.
  @visibleForTesting
  ArgResults? testArgResults;

  /// The parent command runner used for testing purposes only.
  @visibleForTesting
  ShorebirdCliCommandRunner? testRunner;

  /// [ArgResults] for the current command.
  ArgResults get results => testArgResults ?? argResults!;
}

/// {@template shorebird_proxy_command}
/// A command in the Shorebird CLI that proxies to an underlying process.
/// {@endtemplate}
abstract class ShorebirdProxyCommand extends ShorebirdCommand {
  @override
  ArgParser get argParser => ArgParser.allowAnything();
}
