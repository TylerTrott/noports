import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:noports_core/src/common/file_system_utils.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';

mixin SSHNPLocalFileMixin on SSHNPImpl {
  String? identityFile;
  late final String homeDirectory;
  late final String sshHomeDirectory;
  late final String sshnpHomeDirectory;

  final bool _isValidPlatform =
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  @override
  Future<void> init() async {
    await super.init();

    if (!params.allowLocalFileSystem) {
      throw SSHNPError(
          'The current client type requires allowLocalFileSystem to be true: $runtimeType');
    }
    if (!_isValidPlatform) {
      throw SSHNPError(
          'The current platform is not supported: ${Platform.operatingSystem}');
    }
    logger.info('Initializing local file system');
    try {
      homeDirectory = getHomeDirectory(throwIfNull: true)!;
      logger.info('got homeDirectory: $homeDirectory');
    } catch (e, s) {
      throw SSHNPError('Unable to determine the home directory',
          error: e, stackTrace: s);
    }

    if (params.allowLocalFileSystem &&
        params.identityFile == null &&
        params.sshKeyPair != null) {
      logger.info('Writing identity file');
      var (_, privateKey) = await writeEphemeralSshKeys(
        keyPair: params.sshKeyPair!,
        sessionId: sessionId,
        prefix: 'identity_',
      );

      identityFile = privateKey;
    }

    sshHomeDirectory = getDefaultSshDirectory(homeDirectory);
    sshnpHomeDirectory = getDefaultSshnpDirectory(homeDirectory);
  }

  @protected
  Future<bool> deleteFile(String fileName) async {
    try {
      final file = File(fileName);
      await file.delete();
      return true;
    } catch (e) {
      logger.severe("Error deleting file : $fileName");
      return false;
    }
  }

  @override
  Future<void> cleanUp() async {
    await super.cleanUp();
    logger.info('Cleaning up local file system');
    if (params.allowLocalFileSystem &&
        params.identityFile == null &&
        params.sshKeyPair != null) {
      logger.info('Deleting identity file');
      await cleanUpEphemeralSshKeys(sessionId: sessionId, prefix: 'identity_');
    }
  }
}
