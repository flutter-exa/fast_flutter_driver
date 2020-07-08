import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:fast_flutter_driver_tool/src/preparing_tests/command_line/streams.dart'
    as streams;
import 'package:fast_flutter_driver_tool/src/preparing_tests/devices.dart'
    as devices;
import 'package:fast_flutter_driver_tool/src/preparing_tests/parameters.dart';
import 'package:fast_flutter_driver_tool/src/preparing_tests/testing.dart'
    as tested;
import 'package:fast_flutter_driver_tool/src/running_tests/parameters.dart';
import 'package:fast_flutter_driver_tool/src/utils/system.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

void main() {
  Logger logger;
  setUp(() {
    logger = _MockLogger();
  });

  group('setup', () {
    tearDown(() {
      linuxOverride = null;
    });

    test('overrides resolution on linux', () async {
      linuxOverride = true;
      final parser = scriptParameters;
      final args = parser.parse(['-r', '1x1']);

      await IOOverrides.runZoned(
        () async {
          await tested.setUp(
            args,
            () async {},
            logger: logger,
          );
        },
        getCurrentDirectory: () {
          final mockDir = _MockDirectory();
          when(mockDir.path).thenReturn('');
          return mockDir;
        },
        createFile: (name) {
          if (name.endsWith('window_configuration.cc_copy')) {
            final file = _MockFile();
            when(file.existsSync()).thenReturn(false);
            return file;
          }
          File resolutionFile;
          resolutionFile = _MockFile();
          when(resolutionFile.existsSync()).thenReturn(true);
          when(resolutionFile.readAsString()).thenAnswer((_) async => '');
          return resolutionFile;
        },
      );

      expect(
        verify(logger.trace(captureAny)).captured.single,
        'Overriding resolution',
      );
    });

    test('runs tests straight away on non linux', () async {
      linuxOverride = false;
      bool haveRunTests = false;

      await tested.setUp(
        scriptParameters.parse(['-r', '1x1']),
        () async {
          haveRunTests = true;
        },
        logger: logger,
      );

      verifyNever(logger.trace(any));
      expect(haveRunTests, isTrue);
    });
  });

  group('test', () {
    test('builds application', () {
      final commands = <String>[];
      tested.test(
        outputFactory: streams.output,
        inputFactory: streams.input,
        run: (
          String command, {
          streams.OutputCommandLineStream stdout,
          streams.InputCommandLineStream stdin,
          streams.OutputCommandLineStream stderr,
        }) async {
          commands.add(command);
        },
        logger: logger,
        testFile: 'generic_test.dart',
        withScreenshots: false,
        language: 'pl',
        resolution: '800x600',
        platform: TestPlatform.android,
        device: devices.device,
      );

      expect(
        commands,
        contains('flutter run -d ${devices.device} --target=generic.dart'),
      );
    });

    test('builds application for specyfic device', () {
      final commands = <String>[];
      const device = 'some_special_device';
      tested.test(
        outputFactory: streams.output,
        inputFactory: streams.input,
        run: (
          String command, {
          streams.OutputCommandLineStream stdout,
          streams.InputCommandLineStream stdin,
          streams.OutputCommandLineStream stderr,
        }) async {
          commands.add(command);
        },
        logger: logger,
        testFile: 'generic_test.dart',
        withScreenshots: false,
        language: 'pl',
        resolution: '800x600',
        platform: TestPlatform.android,
        device: device,
      );

      expect(
        commands,
        contains('flutter run -d $device --target=generic.dart'),
      );
    });

    test('runs tests application', () async {
      final commands = <String>[];
      await tested.test(
        outputFactory: streams.output,
        inputFactory: () => _MockInputCommandLineStream(),
        run: (
          String command, {
          streams.OutputCommandLineStream stdout,
          streams.InputCommandLineStream stdin,
          streams.OutputCommandLineStream stderr,
        }) async {
          commands.add(command);
          if (command ==
              'flutter run -d ${devices.device} --target=generic.dart') {
            stdout.stream.add(
              utf8.encode(
                  'is available at: http://127.0.0.1:50512/CKxutzePXlo/'),
            );
          }
        },
        logger: logger,
        testFile: 'generic_test.dart',
        withScreenshots: false,
        language: 'pl',
        resolution: '800x600',
        platform: TestPlatform.android,
        device: devices.device,
      );

      expect(
        commands,
        contains(
            'dart generic_test.dart -u http://127.0.0.1:50512/CKxutzePXlo/ -r 800x600 -l pl -p android'),
      );
    });
  });
}

class _MockDirectory extends Mock implements Directory {}

class _MockFile extends Mock implements File {}

class _MockLogger extends Mock implements Logger {}

class _MockInputCommandLineStream extends Mock
    implements streams.InputCommandLineStream {}
