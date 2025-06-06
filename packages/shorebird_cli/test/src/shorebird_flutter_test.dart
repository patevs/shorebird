// cspell:words revis
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:scoped_deps/scoped_deps.dart';
import 'package:shorebird_cli/src/executables/executables.dart';
import 'package:shorebird_cli/src/logging/logging.dart';
import 'package:shorebird_cli/src/platform.dart';
import 'package:shorebird_cli/src/shorebird_env.dart';
import 'package:shorebird_cli/src/shorebird_flutter.dart';
import 'package:shorebird_cli/src/shorebird_process.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group(ShorebirdFlutter, () {
    const flutterRevision = 'flutter-revision';
    late Directory shorebirdRoot;
    late Directory flutterDirectory;
    late Git git;
    late ShorebirdLogger logger;
    late Platform platform;
    late Progress progress;
    late ShorebirdEnv shorebirdEnv;
    late ShorebirdProcess process;
    late ShorebirdProcessResult versionProcessResult;
    late ShorebirdProcessResult precacheProcessResult;
    late ShorebirdFlutter shorebirdFlutter;

    R runWithOverrides<R>(R Function() body) {
      return runScoped(
        body,
        values: {
          gitRef.overrideWith(() => git),
          loggerRef.overrideWith(() => logger),
          platformRef.overrideWith(() => platform),
          processRef.overrideWith(() => process),
          shorebirdEnvRef.overrideWith(() => shorebirdEnv),
        },
      );
    }

    setUp(() {
      shorebirdRoot = Directory.systemTemp.createTempSync();
      flutterDirectory = Directory(p.join(shorebirdRoot.path, 'flutter'));
      git = MockGit();
      logger = MockShorebirdLogger();
      progress = MockProgress();
      shorebirdEnv = MockShorebirdEnv();
      platform = MockPlatform();
      process = MockShorebirdProcess();
      versionProcessResult = MockShorebirdProcessResult();
      precacheProcessResult = MockShorebirdProcessResult();
      shorebirdFlutter = runWithOverrides(ShorebirdFlutter.new);

      when(
        () => git.clone(
          url: any(named: 'url'),
          outputDirectory: any(named: 'outputDirectory'),
          args: any(named: 'args'),
        ),
      ).thenAnswer((_) async => {});
      when(
        () => git.checkout(
          directory: any(named: 'directory'),
          revision: any(named: 'revision'),
        ),
      ).thenAnswer((_) async => {});
      when(
        () => git.status(
          directory: p.join(flutterDirectory.parent.path, flutterRevision),
          args: ['--untracked-files=no', '--porcelain'],
        ),
      ).thenAnswer((_) async => '');
      when(
        () => git.revParse(
          revision: any(named: 'revision'),
          directory: any(named: 'directory'),
        ),
      ).thenAnswer((_) async => flutterRevision);
      when(
        () => git.forEachRef(
          directory: any(named: 'directory'),
          contains: any(named: 'contains'),
          format: any(named: 'format'),
          pattern: any(named: 'pattern'),
        ),
      ).thenAnswer((_) async => 'origin/flutter_release/3.10.6');
      when(() => logger.progress(any())).thenReturn(progress);
      when(() => platform.isMacOS).thenReturn(false);
      when(() => shorebirdEnv.flutterDirectory).thenReturn(flutterDirectory);
      when(() => shorebirdEnv.flutterRevision).thenReturn(flutterRevision);
      when(
        () => process.run('flutter', ['--version'], useVendedFlutter: false),
      ).thenAnswer((_) async => versionProcessResult);
      when(() => versionProcessResult.exitCode).thenReturn(0);
      when(
        () => process.run(
          'flutter',
          any(that: contains('precache')),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).thenAnswer((_) async => precacheProcessResult);
      when(() => versionProcessResult.exitCode).thenReturn(0);
    });

    group('precacheArgs', () {
      group('when running on macOS', () {
        setUp(() {
          when(() => platform.isMacOS).thenReturn(true);
        });

        test('includes ios in platform list', () async {
          expect(
            runWithOverrides(() => shorebirdFlutter.precacheArgs),
            contains('--ios'),
          );
        });
      });

      group('when not running on macOS', () {
        setUp(() {
          when(() => platform.isMacOS).thenReturn(false);
        });

        test('does not include ios in platform list', () {
          expect(
            runWithOverrides(() => shorebirdFlutter.precacheArgs),
            isNot(contains('--ios')),
          );
        });
      });
    });

    group('getConfig', () {
      late ShorebirdProcessResult configProcessResult;

      setUp(() {
        configProcessResult = MockProcessResult();
        when(
          () => process.runSync(any(), any()),
        ).thenReturn(configProcessResult);
      });

      group('when process exists with non-zero code', () {
        setUp(() {
          when(
            () => configProcessResult.exitCode,
          ).thenReturn(ExitCode.software.code);
          when(() => configProcessResult.stderr).thenReturn('oops');
        });

        test('returns empty map', () {
          expect(runWithOverrides(shorebirdFlutter.getConfig), isEmpty);
          verify(
            () => process.runSync('flutter', ['config', '--list']),
          ).called(1);
        });
      });

      group('when process completes successfully', () {
        setUp(() {
          when(() => configProcessResult.stdout).thenReturn(r'''
All Settings:
  enable-web: (Not set)
  enable-linux-desktop: (Not set)
  enable-macos-desktop: (Not set)
  enable-windows-desktop: (Not set)
  enable-android: (Not set)
  enable-ios: (Not set)
  enable-fuchsia: (Not set) (Unavailable)
  enable-custom-devices: (Not set)
  cli-animations: (Not set)
  enable-native-assets: (Not set) (Unavailable)
  enable-flutter-preview: (Not set) (Unavailable)
  enable-swift-package-manager: (Not set)
  explicit-package-dependencies: (Not set)
  jdk-dir: C:\Program Files\Android\Android Studio\jdk
  ''');
          when(
            () => configProcessResult.exitCode,
          ).thenReturn(ExitCode.success.code);
        });

        test('returns correct config map', () {
          expect(
            runWithOverrides(shorebirdFlutter.getConfig),
            equals({
              'enable-web': '(Not set)',
              'enable-linux-desktop': '(Not set)',
              'enable-macos-desktop': '(Not set)',
              'enable-windows-desktop': '(Not set)',
              'enable-android': '(Not set)',
              'enable-ios': '(Not set)',
              'enable-fuchsia': '(Not set) (Unavailable)',
              'enable-custom-devices': '(Not set)',
              'cli-animations': '(Not set)',
              'enable-native-assets': '(Not set) (Unavailable)',
              'enable-flutter-preview': '(Not set) (Unavailable)',
              'enable-swift-package-manager': '(Not set)',
              'explicit-package-dependencies': '(Not set)',
              'jdk-dir': r'C:\Program Files\Android\Android Studio\jdk',
            }),
          );
        });
      });
    });

    group('getSystemVersion', () {
      test(
        'throws ProcessException when process exits with non-zero code',
        () async {
          const error = 'oops';
          when(
            () => versionProcessResult.exitCode,
          ).thenReturn(ExitCode.software.code);
          when(() => versionProcessResult.stderr).thenReturn(error);
          await expectLater(
            runWithOverrides(shorebirdFlutter.getSystemVersion),
            throwsA(isA<ProcessException>()),
          );
          verify(
            () =>
                process.run('flutter', ['--version'], useVendedFlutter: false),
          ).called(1);
        },
      );

      test('returns null when cannot parse version', () async {
        when(() => versionProcessResult.stdout).thenReturn('');
        await expectLater(
          runWithOverrides(shorebirdFlutter.getSystemVersion),
          completion(isNull),
        );
        verify(
          () => process.run('flutter', ['--version'], useVendedFlutter: false),
        ).called(1);
      });

      test('returns version when able to parse the string', () async {
        when(() => versionProcessResult.stdout).thenReturn('''
Flutter 3.10.6 • channel stable • git@github.com:flutter/flutter.git
Framework • revision f468f3366c (4 weeks ago) • 2023-07-12 15:19:05 -0700
Engine • revision cdbeda788a
Tools • Dart 3.0.6 • DevTools 2.23.1''');
        await expectLater(
          runWithOverrides(shorebirdFlutter.getSystemVersion),
          completion(equals('3.10.6')),
        );
        verify(
          () => process.run('flutter', ['--version'], useVendedFlutter: false),
        ).called(1);
      });
    });

    group('getVersionAndRevision', () {
      group('when unable to determine version', () {
        const error = 'oops';
        setUp(() {
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              contains: any(named: 'contains'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenThrow(
            ProcessException(
              'git',
              [
                'for-each-ref',
                '--format',
                '%(refname:short)',
                'refs/remotes/origin/flutter_release/*',
              ],
              error,
              ExitCode.software.code,
            ),
          );
        });

        test('returns unknown (<revision>)', () async {
          await expectLater(
            runWithOverrides(shorebirdFlutter.getVersionAndRevision),
            completion(equals('unknown (${flutterRevision.substring(0, 10)})')),
          );
        });
      });

      test('returns correct version and revision', () async {
        await expectLater(
          runWithOverrides(shorebirdFlutter.getVersionAndRevision),
          completion(equals('3.10.6 (${flutterRevision.substring(0, 10)})')),
        );
      });
    });

    group('resolveFlutterRevision', () {
      group('when input is a semver version', () {
        test(
          'returns the revision associated with the version if it exists',
          () async {
            final revision = await runWithOverrides(
              () => shorebirdFlutter.resolveFlutterRevision('3.10.6'),
            );
            expect(revision, equals(flutterRevision));
          },
        );
      });

      group('when input is a commit hash that maps to a Flutter version', () {
        setUp(() {
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              contains: any(named: 'contains'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenAnswer((_) async => 'origin/flutter_release/1.2.3');
        });

        test('returns the input string', () async {
          final revision = await runWithOverrides(
            () => shorebirdFlutter.resolveFlutterRevision('deadbeef'),
          );
          expect(revision, equals('deadbeef'));
        });
      });

      group(
        'when input is not a commit hash that maps to a Flutter version',
        () {
          setUp(() {
            when(
              () => git.forEachRef(
                directory: any(named: 'directory'),
                contains: any(named: 'contains'),
                format: any(named: 'format'),
                pattern: any(named: 'pattern'),
              ),
            ).thenAnswer((_) async => '');
          });

          test('returns the input string', () async {
            final revision = await runWithOverrides(
              () => shorebirdFlutter.resolveFlutterRevision('not-a-version'),
            );
            expect(revision, isNull);
          });
        },
      );

      group('when exception occurs doing revision lookup', () {
        setUp(() {
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              contains: any(named: 'contains'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenThrow(Exception('oops'));
        });

        test('returns null', () async {
          final revision = await runWithOverrides(
            () => shorebirdFlutter.resolveFlutterRevision('not-a-version'),
          );
          expect(revision, isNull);
        });
      });
    });

    group('resolveFlutterVersion', () {
      group('when input is a semver version', () {
        test(
          'returns the revision associated with the version if it exists',
          () async {
            final revision = await runWithOverrides(
              () => shorebirdFlutter.resolveFlutterVersion('3.10.6'),
            );
            expect(revision, equals(Version(3, 10, 6)));
          },
        );
      });

      group('when input is not a recognized commit hash', () {
        setUp(() {
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              contains: any(named: 'contains'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenAnswer((_) async => '');
        });

        test('returns null', () async {
          final revision = await runWithOverrides(
            () => shorebirdFlutter.resolveFlutterVersion('not-a-version'),
          );
          expect(revision, isNull);
        });
      });

      group('when commit lookup fails', () {
        setUp(() {
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              contains: any(named: 'contains'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenThrow(Exception('oops'));
        });

        test('returns null', () async {
          final revision = await runWithOverrides(
            () => shorebirdFlutter.resolveFlutterVersion('not-a-version'),
          );
          expect(revision, isNull);
        });
      });

      group('when input is a recognized commit hash', () {
        setUp(() {
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              contains: any(named: 'contains'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenAnswer((_) async => 'origin/flutter_release/1.2.3');
        });

        test('returns a parsed version', () async {
          final revision = await runWithOverrides(
            () => shorebirdFlutter.resolveFlutterVersion('deadbeef'),
          );
          expect(revision, equals(Version(1, 2, 3)));
        });
      });
    });

    group('getRevisionForVersion', () {
      const version = '3.16.3';
      const exception = ProcessException('git', ['rev-parse']);

      group('when process exits with non-zero code', () {
        setUp(() {
          when(
            () => git.revParse(
              revision: any(named: 'revision'),
              directory: any(named: 'directory'),
            ),
          ).thenThrow(exception);
        });

        test('throws exception', () async {
          await expectLater(
            runWithOverrides(
              () => shorebirdFlutter.getRevisionForVersion(version),
            ),
            throwsA(exception),
          );
          verify(
            () => git.revParse(
              revision: 'refs/remotes/origin/flutter_release/$version',
              directory: any(named: 'directory'),
            ),
          ).called(1);
        });
      });

      group('when cannot parse revision', () {
        setUp(() {
          when(
            () => git.revParse(
              revision: any(named: 'revision'),
              directory: any(named: 'directory'),
            ),
          ).thenAnswer((_) async => '');
        });

        test('returns null', () async {
          await expectLater(
            runWithOverrides(
              () => shorebirdFlutter.getRevisionForVersion(version),
            ),
            completion(isNull),
          );
          verify(
            () => git.revParse(
              revision: 'refs/remotes/origin/flutter_release/$version',
              directory: any(named: 'directory'),
            ),
          ).called(1);
        });
      });

      group('when able to parse the string', () {
        const revision = '771d07b2cf97cf107bae6eeedcf41bdc9db772fa';
        setUp(() {
          when(
            () => git.revParse(
              revision: any(named: 'revision'),
              directory: any(named: 'directory'),
            ),
          ).thenAnswer(
            (_) async =>
                '''
$revision
        ''',
          );
        });

        test('returns revision', () async {
          await expectLater(
            runWithOverrides(
              () => shorebirdFlutter.getRevisionForVersion(version),
            ),
            completion(equals(revision)),
          );
          verify(
            () => git.revParse(
              revision: 'refs/remotes/origin/flutter_release/$version',
              directory: any(named: 'directory'),
            ),
          ).called(1);
        });
      });
    });

    group('getVersionString', () {
      group('when process exits with non-zero code', () {
        const error = 'oops';

        setUp(() {
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              contains: any(named: 'contains'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenThrow(
            ProcessException(
              'git',
              [
                'for-each-ref',
                '--format',
                '%(refname:short)',
                'refs/remotes/origin/flutter_release/*',
              ],
              error,
              ExitCode.software.code,
            ),
          );
        });

        test('throws ProcessException', () async {
          await expectLater(
            runWithOverrides(shorebirdFlutter.getVersionString),
            throwsA(isA<ProcessException>()),
          );
          verify(
            () => git.forEachRef(
              directory: p.join(flutterDirectory.parent.path, flutterRevision),
              contains: flutterRevision,
              format: '%(refname:short)',
              pattern: 'refs/remotes/origin/flutter_release/*',
            ),
          ).called(1);
        });
      });

      group('when cannot parse version', () {
        setUp(() {
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              contains: any(named: 'contains'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenAnswer((_) async => '');
        });

        test('returns null', () async {
          await expectLater(
            runWithOverrides(shorebirdFlutter.getVersionString),
            completion(isNull),
          );
          verify(
            () => git.forEachRef(
              directory: p.join(flutterDirectory.parent.path, flutterRevision),
              contains: flutterRevision,
              format: '%(refname:short)',
              pattern: 'refs/remotes/origin/flutter_release/*',
            ),
          ).called(1);
        });
      });

      group('when able to parse the string', () {
        test('returns version', () async {
          await expectLater(
            runWithOverrides(shorebirdFlutter.getVersionString),
            completion(equals('3.10.6')),
          );
          verify(
            () => git.forEachRef(
              directory: p.join(flutterDirectory.parent.path, flutterRevision),
              contains: flutterRevision,
              format: '%(refname:short)',
              pattern: 'refs/remotes/origin/flutter_release/*',
            ),
          ).called(1);
        });
      });
    });

    group('getVersion', () {
      group('when getVersionString returns null', () {
        setUp(() {
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              contains: any(named: 'contains'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenAnswer((_) async => '');
        });

        test('returns null', () {
          expect(
            runWithOverrides(shorebirdFlutter.getVersion),
            completion(isNull),
          );
        });
      });

      group('when getVersionString returns an invalid string', () {
        setUp(() {
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              contains: any(named: 'contains'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenAnswer((_) async => 'not a version');
        });

        test('returns null', () {
          expect(
            runWithOverrides(shorebirdFlutter.getVersion),
            completion(isNull),
          );
        });
      });

      group('when getVersionString returns a valid string', () {
        setUp(() {
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              contains: any(named: 'contains'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenAnswer((_) async => '3.10.6');
        });

        test('returns the version', () {
          expect(
            runWithOverrides(shorebirdFlutter.getVersion),
            completion(equals(Version(3, 10, 6))),
          );
        });
      });
    });

    group('getVersions', () {
      const format = '%(refname:short)';
      const pattern = 'refs/remotes/origin/flutter_release/*';
      test('returns a list of versions', () async {
        const versions = [
          '3.10.0',
          '3.10.1',
          '3.10.2',
          '3.10.3',
          '3.10.4',
          '3.10.5',
          '3.10.6',
        ];
        const output = '''
origin/flutter_release/3.10.0
origin/flutter_release/3.10.1
origin/flutter_release/3.10.2
origin/flutter_release/3.10.3
origin/flutter_release/3.10.4
origin/flutter_release/3.10.5
origin/flutter_release/3.10.6''';
        when(
          () => git.forEachRef(
            directory: any(named: 'directory'),
            format: any(named: 'format'),
            pattern: any(named: 'pattern'),
          ),
        ).thenAnswer((_) async => output);

        await expectLater(
          runWithOverrides(shorebirdFlutter.getVersions),
          completion(equals(versions)),
        );
        verify(
          () => git.forEachRef(
            directory: p.join(flutterDirectory.parent.path, flutterRevision),
            format: format,
            pattern: pattern,
          ),
        ).called(1);
      });

      test(
        'throws ProcessException when git command exits non-zero code',
        () async {
          const errorMessage = 'oh no!';
          when(
            () => git.forEachRef(
              directory: any(named: 'directory'),
              format: any(named: 'format'),
              pattern: any(named: 'pattern'),
            ),
          ).thenThrow(
            ProcessException(
              'git',
              ['for-each-ref', '--format', format, pattern],
              errorMessage,
              ExitCode.software.code,
            ),
          );

          expect(
            runWithOverrides(shorebirdFlutter.getVersions),
            throwsA(
              isA<ProcessException>().having(
                (e) => e.message,
                'message',
                errorMessage,
              ),
            ),
          );
        },
      );
    });

    group('installRevision', () {
      const revision = 'test-revision';

      test('does nothing if the revision is already installed', () async {
        Directory(
          p.join(flutterDirectory.parent.path, revision),
        ).createSync(recursive: true);

        await runWithOverrides(
          () => shorebirdFlutter.installRevision(revision: revision),
        );

        verifyNever(
          () => git.clone(
            url: any(named: 'url'),
            outputDirectory: any(named: 'outputDirectory'),
            args: any(named: 'args'),
          ),
        );
        verifyNever(
          () => process.run('flutter', any(that: contains('precache'))),
        );
      });

      test('throws exception if unable to clone', () async {
        final exception = Exception('oops');
        when(
          () => git.clone(
            url: any(named: 'url'),
            outputDirectory: any(named: 'outputDirectory'),
            args: any(named: 'args'),
          ),
        ).thenThrow(exception);

        await expectLater(
          runWithOverrides(
            () => shorebirdFlutter.installRevision(revision: revision),
          ),
          throwsA(exception),
        );

        verify(
          () => git.clone(
            url: ShorebirdFlutter.flutterGitUrl,
            outputDirectory: p.join(flutterDirectory.parent.path, revision),
            args: ['--filter=tree:0', '--no-checkout'],
          ),
        ).called(1);
        verifyNever(
          () => process.run('flutter', any(that: contains('precache'))),
        );
      });

      test('throws exception if unable to checkout revision', () async {
        final exception = Exception('oops');
        when(
          () => git.checkout(
            directory: any(named: 'directory'),
            revision: any(named: 'revision'),
          ),
        ).thenThrow(exception);

        await expectLater(
          runWithOverrides(
            () => shorebirdFlutter.installRevision(revision: revision),
          ),
          throwsA(exception),
        );
        verify(
          () => git.clone(
            url: ShorebirdFlutter.flutterGitUrl,
            outputDirectory: p.join(flutterDirectory.parent.path, revision),
            args: ['--filter=tree:0', '--no-checkout'],
          ),
        ).called(1);
        verify(
          () => git.checkout(
            directory: p.join(flutterDirectory.parent.path, revision),
            revision: revision,
          ),
        ).called(1);
        verify(
          () => logger.progress('Installing Flutter 3.10.6 (test-revis)'),
        ).called(1);
        verify(
          () => progress.fail('Failed to install Flutter 3.10.6 (test-revis)'),
        ).called(1);
      });

      group('when unable to precache', () {
        setUp(() {
          when(
            () => process.run(
              'flutter',
              any(that: contains('precache')),
              workingDirectory: any(named: 'workingDirectory'),
            ),
          ).thenThrow(Exception('oh no!'));
        });

        test('logs error and continues', () async {
          await expectLater(
            runWithOverrides(
              () => shorebirdFlutter.installRevision(revision: revision),
            ),
            completes,
          );
          verify(
            () => process.run(
              'flutter',
              [
                'precache',
                ...runWithOverrides(() => shorebirdFlutter.precacheArgs),
              ],
              workingDirectory: p.join(flutterDirectory.parent.path, revision),
            ),
          ).called(1);

          verify(
            () => progress.fail('Failed to precache Flutter 3.10.6'),
          ).called(1);
          verify(
            () => logger.info(
              '''This is not a critical error, but your next build make take longer than usual.''',
            ),
          ).called(1);
        });
      });

      group('when clone and checkout succeed', () {
        test('completes successfully', () async {
          await expectLater(
            runWithOverrides(
              () => shorebirdFlutter.installRevision(revision: revision),
            ),
            completes,
          );
          verify(
            () => process.run(
              'flutter',
              [
                'precache',
                ...runWithOverrides(() => shorebirdFlutter.precacheArgs),
              ],
              workingDirectory: p.join(flutterDirectory.parent.path, revision),
            ),
          ).called(1);
          verify(
            () => logger.progress('Installing Flutter 3.10.6 (test-revis)'),
          ).called(1);
          // Once for the installation and once for the precache.
          verify(progress.complete).called(2);
        });
      });
    });

    group('isPorcelain', () {
      test('returns true when status is empty', () async {
        await expectLater(
          runWithOverrides(() => shorebirdFlutter.isUnmodified()),
          completion(isTrue),
        );
        verify(
          () => git.status(
            directory: p.join(flutterDirectory.parent.path, flutterRevision),
            args: ['--untracked-files=no', '--porcelain'],
          ),
        ).called(1);
      });

      test('returns false when status is not empty', () async {
        when(
          () => git.status(
            directory: any(named: 'directory'),
            args: any(named: 'args'),
          ),
        ).thenAnswer((_) async => 'M some/file');
        await expectLater(
          runWithOverrides(() => shorebirdFlutter.isUnmodified()),
          completion(isFalse),
        );
        verify(
          () => git.status(
            directory: p.join(flutterDirectory.parent.path, flutterRevision),
            args: ['--untracked-files=no', '--porcelain'],
          ),
        ).called(1);
      });

      test(
        'throws ProcessException when git command exits non-zero code',
        () async {
          const errorMessage = 'oh no!';
          when(
            () => git.status(
              directory: any(named: 'directory'),
              args: any(named: 'args'),
            ),
          ).thenThrow(
            ProcessException(
              'git',
              ['status'],
              errorMessage,
              ExitCode.software.code,
            ),
          );

          expect(
            runWithOverrides(() => shorebirdFlutter.isUnmodified()),
            throwsA(
              isA<ProcessException>().having(
                (e) => e.message,
                'message',
                errorMessage,
              ),
            ),
          );
        },
      );
    });

    group('formatVersion', () {
      test('returns the correct formatted value', () {
        expect(
          runWithOverrides(
            () => shorebirdFlutter.formatVersion(
              version: '3.10.6',
              revision: '771d07b2cf97cf107bae6eeedcf41bdc9db772fa',
            ),
          ),
          equals('3.10.6 (771d07b2cf)'),
        );
      });

      group('when version is null', () {
        test('returns unknown for the version', () {
          expect(
            runWithOverrides(
              () => shorebirdFlutter.formatVersion(
                version: null,
                revision: '771d07b2cf97cf107bae6eeedcf41bdc9db772fa',
              ),
            ),
            equals('unknown (771d07b2cf)'),
          );
        });
      });
    });
  });
}
