class MdnsInfo {
  MdnsInfo({
    required this.mdnsName,
    required this.mdnsPort,
    required this.mdnsDomainName,
    required this.mdnsServiceType,
  });

  /// Also can be called target
  String mdnsName;
  int mdnsPort;

  /// Also can be called bundleId
  String mdnsDomainName;
  String mdnsServiceType;
}
