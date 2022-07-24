List<String> srvRecordsList = [
  '_uscan._tcp', // Any HP-compatible network scanners
  '_uscans._tcp', // Any SSL/TLS-capable HP-compatible network scanners
  '_privet._tcp', // Any Google CloudPrint-capable printers or print services
  '_http-alt._tcp',
  '_scanner._tcp', // Are there any Bonjour-capable scanners
  '_home-assistant._tcp',
  '_pdl-datastream._tcp', // Any HP JetDirect-style network printers
  '_ipp._tcp', // Are there any printers using the IPP protocol
  '_ipps._tcp', // Any SSL/TLS capable IPP printers
  '_http._tcp',
  '_ldap._tcp',
  '_gc._tcp',
  '_kerberos._tcp',
  '_kpasswd._tcp',
  '_airplay._tcp', // Any Apple AirPlay-capable video displays here_ipps
  '_raop._tcp', // Any Apple AirPlay-capable audio devices
  '_ippusb._tcp', // Are there any shared printers that are using the IPP-over-USB protocol, i.e. USB-connected printers shared by a Mac
  '_printer._tcp', // Any kinds of shared printers at all
  '_ptp._tcp', // Any devices supporting the Picture Transfer Protocol over this network
  '_googlecast._tcp', // Is there a ChromeCast-capable device in this network
  '_airport._tcp', // Any Apple AirPort WiFi APs
];
