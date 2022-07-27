class MdnsInfo {
  MdnsInfo({
    required this.mdnsName,
    required this.mdnsPort,
    required this.mdnsDomainName,
    required this.mdnsServiceType,
    required this.mdnsSrvTarget,
  });

  /// Also can be called target
  String mdnsName;
  String mdnsSrvTarget;
  int mdnsPort;

  /// Also can be called bundleId
  String mdnsDomainName;

  /// Srv record of the dns
  String mdnsServiceType;

  /// mDNS name without the ._tcp.local
  String getOnlyTheStartOfMdnsName() {
    return mdnsName.substring(0, mdnsName.indexOf('.'));
  }
}
