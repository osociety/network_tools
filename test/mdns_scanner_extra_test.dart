import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  final MdnsScannerServiceImpl service = MdnsScannerServiceImpl();

  const PtrResourceRecord ptr = PtrResourceRecord(
    '_ipp._tcp.local',
    0,
    domainName: 'local',
  );
  const SrvResourceRecord srv = SrvResourceRecord(
    'device._ipp._tcp.local',
    0,
    target: 'device.local',
    port: 631,
    priority: 0,
    weight: 0,
  );
  const TxtResourceRecord txt = TxtResourceRecord(
    'device._ipp._tcp.local',
    0,
    text: 'rp=printers/device',
  );

  group('MdnsScannerService singleton', () {
    test('the last created implementation is the exposed instance', () {
      expect(MdnsScannerService.instance, same(service));
    });
  });

  group('convertSrvToHostName', () {
    test('builds an ActiveHost carrying the mdns info', () async {
      final host = service.convertSrvToHostName(
        internetAddress: InternetAddress('192.168.1.10'),
        ptr: ptr,
        srv: srv,
        txt: txt,
      );

      expect(host.address, '192.168.1.10');
      final info = await host.mdnsInfo;
      expect(info, isNotNull);
      expect(info!.mdnsName, 'device._ipp._tcp.local');
      expect(info.mdnsSrvTarget, 'device.local');
      expect(info.mdnsPort, 631);
      expect(info.mdnsServiceType, '_ipp._tcp');
      expect(info.textRecord, 'rp=printers/device');
    });
  });

  group('findAllActiveHostForSrv', () {
    test('falls back to 0.0.0.0 when the IPv4 lookup fails', () async {
      final client = MDnsClient();

      final hosts = await service.findAllActiveHostForSrv(
        addressType: InternetAddress.anyIPv4,
        client: client,
        ptr: ptr,
        srv: srv,
        txt: txt,
      );

      expect(hosts.single.address, '0.0.0.0');
      expect((await hosts.single.mdnsInfo)!.mdnsServiceType, '_ipp._tcp');
    });

    test('falls back to 0.0.0.0 when the IPv6 lookup fails', () async {
      final client = MDnsClient();

      final hosts = await service.findAllActiveHostForSrv(
        addressType: InternetAddress.anyIPv6,
        client: client,
        ptr: ptr,
        srv: srv,
        txt: txt,
      );

      expect(hosts.single.address, '0.0.0.0');
    });
  });
}
