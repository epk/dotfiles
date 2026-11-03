# Network constants for the guests. The microvm, vpn and workshop modules read them.
{
  # Guests have no IPv6, so they use only IPv4 resolvers.
  guestNameservers = [
    "1.1.1.1"
    "9.9.9.9"
  ];
  # Guest traffic must not reach these ranges.
  nonPublicV4 = [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "100.64.0.0/10"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.0.0.0/24"
    "192.0.2.0/24"
    "192.168.0.0/16"
    "198.18.0.0/15"
    "198.51.100.0/24"
    "203.0.113.0/24"
    "224.0.0.0/4"
    "240.0.0.0/4"
  ];
}
