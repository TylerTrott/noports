import 'package:args/args.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/file_system_utils.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/common/validation_utils.dart';

class SshnpdParams {
  final String device;
  final String username;
  final String homeDirectory;
  final String managerAtsign;
  final String atKeysFilePath;
  final String deviceAtsign;
  final bool verbose;
  final bool makeDeviceInfoVisible;
  final bool addSshPublicKeys;
  final bool delegateAuthChecks;
  final SupportedSshClient sshClient;
  final String rootDomain;
  final int localSshdPort;
  final String ephemeralPermissions;
  final SupportedSshAlgorithm sshAlgorithm;
  final String deviceGroup;

  // Non param variables
  static final ArgParser parser = _createArgParser();
  SshnpdParams({
    required this.device,
    required this.username,
    required this.homeDirectory,
    required this.managerAtsign,
    required this.atKeysFilePath,
    required this.deviceAtsign,
    required this.verbose,
    required this.makeDeviceInfoVisible,
    required this.addSshPublicKeys,
    required this.delegateAuthChecks,
    required this.sshClient,
    required this.rootDomain,
    required this.localSshdPort,
    required this.ephemeralPermissions,
    required this.sshAlgorithm,
    required this.deviceGroup,
  });

  static Future<SshnpdParams> fromArgs(List<String> args) async {
    // Arg check
    ArgResults r = parser.parse(args);

    String deviceAtsign = r['atsign'];
    String managerAtsign = r['manager'];
    String homeDirectory = getHomeDirectory()!;

    // Do we have a device ?
    String device = r['device'];

    SupportedSshClient sshClient = SupportedSshClient.values.firstWhere(
        (c) => c.toString() == r['ssh-client'],
        orElse: () => DefaultSshnpdArgs.sshClient);

    // Do we have an ASCII ?
    if (checkNonAscii(device)) {
      throw ('\nDevice name can only contain alphanumeric characters with a max length of 15');
    }

    return SshnpdParams(
      device: r['device'],
      username: getUserName(throwIfNull: true)!,
      homeDirectory: homeDirectory,
      managerAtsign: managerAtsign,
      atKeysFilePath: r['key-file'] ??
          getDefaultAtKeysFilePath(homeDirectory, deviceAtsign),
      deviceAtsign: deviceAtsign,
      verbose: r['verbose'],
      makeDeviceInfoVisible: r['un-hide'],
      addSshPublicKeys: r['sshpublickey'],
      delegateAuthChecks: r['delegate-auth-checks'],
      sshClient: sshClient,
      rootDomain: r['root-domain'],
      localSshdPort:
          int.tryParse(r['local-sshd-port']) ?? DefaultArgs.localSshdPort,
      ephemeralPermissions: r['ephemeral-permissions'],
      sshAlgorithm: SupportedSshAlgorithm.fromString(r['ssh-algorithm']),
      deviceGroup: r['device-group'],
    );
  }

  static ArgParser _createArgParser() {
    var parser = ArgParser();

    // Basic arguments
    parser.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      aliases: const ['keyFile'],
      help: 'Sending atSign\'s keyFile if not in ~/.atsign/keys/',
    );
    parser.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'atSign of this device',
    );
    parser.addOption(
      'manager',
      abbr: 'm',
      mandatory: true,
      help: 'Managers atSign, that this device will accept triggers from',
    );
    parser.addOption(
      'device',
      abbr: 'd',
      mandatory: false,
      defaultsTo: "default",
      help:
          'Send a trigger to this device, allows multiple devices share an atSign',
    );

    parser.addFlag(
      'sshpublickey',
      abbr: 's',
      defaultsTo: false,
      help:
          'When set, will update authorized_keys to include public key sent by manager',
    );
    parser.addFlag(
      'delegate-auth-checks',
      defaultsTo: false,
      help:
          'When set, sshnpd will listen for messages from multiple atSigns '
          'but check with the [managerAtsign] if this particular client atSign '
          'is currently authorized to connect to this device.',
    );
    parser.addFlag(
      'un-hide',
      abbr: 'u',
      aliases: const ['username'],
      defaultsTo: false,
      help:
          'When set, makes various information visible to the manager atSign - e.g. username, version, etc',
    );
    parser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'More logging',
    );

    parser.addOption('ssh-client',
        mandatory: false,
        defaultsTo: DefaultSshnpdArgs.sshClient.toString(),
        allowed: SupportedSshClient.values
            .map(
              (c) => c.toString(),
            )
            .toList(),
        help: 'What to use for outbound ssh connections.');

    parser.addOption(
      'root-domain',
      mandatory: false,
      defaultsTo: 'root.atsign.org',
      help: 'atDirectory domain',
    );

    parser.addOption(
      'device-group',
      mandatory: false,
      defaultsTo: DefaultSSHNPDArgs.deviceGroupName,
      help: 'The name of this device\'s group. When delegated authorization'
          ' is being used then the group name is sent to the authorizer'
          ' service as well as the device name, this daemon\'s atSign, '
          ' and the client atSign which is requesting a connection',
    );

    parser.addOption(
      'local-sshd-port',
      help: 'port on which sshd is listening locally on localhost',
      defaultsTo: DefaultArgs.localSshdPort.toString(),
      mandatory: false,
    );

    parser.addOption('ephemeral-permissions',
        help: 'The permissions which will be added to the authorized_keys file'
            ' for the ephemeral public keys which are generated when a client'
            ' is connecting via forward ssh'
            ' e.g. PermitOpen="host-1:3389",PermitOpen="localhost:80"',
        defaultsTo: '',
        mandatory: false);

    parser.addOption(
      'ssh-algorithm',
      defaultsTo: DefaultArgs.sshAlgorithm.toString(),
      help: 'Use RSA 4096 keys rather than the default ED25519 keys',
      allowed: SupportedSshAlgorithm.values.map((c) => c.toString()).toList(),
    );

    return parser;
  }
}
