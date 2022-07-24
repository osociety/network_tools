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

  /// Srv record of the dns
  String mdnsServiceType;

  String getOnlyTheStartOfMdnsName() {
    return mdnsName.substring(0, mdnsName.indexOf('.'));
  }
}
