import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';

void main() {
  PtrResourceRecord ptr(String name) =>
      PtrResourceRecord(name, 0, domainName: 'local');
  SrvResourceRecord srv(String name) => SrvResourceRecord(
    name,
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

  group('MdnsInfo', () {
    test('exposes the underlying resource record values', () {
      final info = MdnsInfo(
        srvResourceRecord: srv('device._ipp._tcp.local'),
        ptrResourceRecord: ptr('_ipp._tcp.local'),
        txtResourceRecord: txt,
      );

      expect(info.mdnsName, 'device._ipp._tcp.local');
      expect(info.mdnsSrvTarget, 'device.local');
      expect(info.mdnsPort, 631);
      expect(info.mdnsDomainName, 'local');
      expect(info.textRecord, 'rp=printers/device');
    });

    test('mdnsServiceType joins the first two name segments', () {
      final info = MdnsInfo(
        srvResourceRecord: srv('device._ipp._tcp.local'),
        ptrResourceRecord: ptr('_ipp._tcp.local'),
        txtResourceRecord: txt,
      );

      expect(info.mdnsServiceType, '_ipp._tcp');
    });

    test('mdnsServiceType handles names without a second segment', () {
      final info = MdnsInfo(
        srvResourceRecord: srv('device'),
        ptrResourceRecord: ptr('_ipp'),
        txtResourceRecord: txt,
      );

      expect(info.mdnsServiceType, '_ipp');
    });

    test('getOnlyTheStartOfMdnsName strips everything after the first dot', () {
      final info = MdnsInfo(
        srvResourceRecord: srv('device._ipp._tcp.local'),
        ptrResourceRecord: ptr('_ipp._tcp.local'),
        txtResourceRecord: txt,
      );

      expect(info.getOnlyTheStartOfMdnsName(), 'device');
    });

    test('getOnlyTheStartOfMdnsName returns the name when it has no dot', () {
      final info = MdnsInfo(
        srvResourceRecord: srv('device'),
        ptrResourceRecord: ptr('_ipp'),
        txtResourceRecord: txt,
      );

      expect(info.getOnlyTheStartOfMdnsName(), 'device');
    });

    test('resource records can be reassigned', () {
      final info = MdnsInfo(
        srvResourceRecord: srv('device._ipp._tcp.local'),
        ptrResourceRecord: ptr('_ipp._tcp.local'),
        txtResourceRecord: txt,
      );

      info.srvResourceRecord = srv('other._http._tcp.local');
      info.ptrResourceRecord = ptr('_http._tcp.local');
      info.txtResourceRecord = const TxtResourceRecord(
        'other._http._tcp.local',
        0,
        text: 'path=/',
      );

      expect(info.mdnsName, 'other._http._tcp.local');
      expect(info.mdnsServiceType, '_http._tcp');
      expect(info.textRecord, 'path=/');
    });
  });
}
