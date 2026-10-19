# Temporary: compare a networkd restart with the old and the new unit dependencies.
{ pkgs, ... }:
let
  host =
    { pkgs, ... }:
    {
      imports = [ ../modules/nixos/microvm-network.nix ];
      networking.useDHCP = false;
      networking.microvm.guests.x = {
        interface = "x-tap";
        hostAddress = "10.77.0.1";
        guestAddress = "10.77.0.2";
        uplink = "eth0";
      };
      # Stand-ins for the microvm.nix TAP and VM units.
      systemd.services."microvm-tap-interfaces@x" = {
        path = [ pkgs.iproute2 ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = "ip tuntap add dev x-tap mode tap; ip link set x-tap up";
      };
      systemd.services."microvm@x" = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
      };
    };
in
pkgs.testers.runNixOSTest {
  name = "networkd-restart";
  nodes.fixed = host;
  nodes.old = {
    imports = [ host ];
    systemd.services.microvm-network-x.requires = [ "systemd-networkd.service" ];
  };
  testScript = ''
    start_all()
    for m in [fixed, old]:
        m.wait_for_unit("microvm@x.service")

    def invocation(m):
        return m.succeed("systemctl show -P InvocationID microvm@x.service").strip()

    before = {m.name: invocation(m) for m in [fixed, old]}
    for m in [fixed, old]:
        m.succeed("systemctl restart systemd-networkd.service")
        m.wait_for_unit("systemd-networkd.service")
        m.wait_for_unit("microvm@x.service")
    after = {m.name: invocation(m) for m in [fixed, old]}
    print(f"InvocationID before={before} after={after}")
    assert after["old"] != before["old"], "old: a networkd restart did not restart the VM"
    assert after["fixed"] == before["fixed"], "fixed: a networkd restart restarted the VM"

    fixed.wait_until_succeeds("ip -4 address show dev x-tap | grep -q 10.77.0.1/30", timeout=30)
    fixed.wait_until_succeeds("ip rule show | grep -q 'iif x-tap lookup main'", timeout=30)
    print(fixed.succeed("ip -4 address show dev x-tap; ip rule show"))

    fixed.succeed("systemctl stop nftables.service")
    fixed.wait_until_fails("systemctl is-active microvm@x.service", timeout=30)
    fixed.fail("systemctl is-active microvm-network-x.service")
  '';
}
