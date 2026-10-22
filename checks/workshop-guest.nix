# Boot the workshop guest services in a test VM. #26 fixed three startup defects that passed eval and build.
{ self, pkgs }:
pkgs.testers.runNixOSTest {
  name = "workshop-guest";
  node.pkgsReadOnly = false;
  node.specialArgs.workshop = {
    storageDirectory = "/var/lib/workshop";
    administratorKeys = [ ];
  };
  node.specialArgs.inputs = self.inputs;
  nodes.guest =
    { lib, ... }:
    {
      imports = [
        self.inputs.microvm.nixosModules.microvm
        ../modules/nixos/guests/workshop.nix
      ];
      # Keep the microvm options, but boot as a test VM instead of Firecracker.
      microvm.guest.enable = false;
      # The guest address and gateway exist only on the host TAP device.
      networking.interfaces = lib.mkForce { };
      networking.defaultGateway = lib.mkForce null;
      virtualisation.memorySize = 4096;
      virtualisation.cores = 2;
    };
  testScript = ''
    guest.wait_for_unit("workshop-browser.service")
    guest.succeed("chrome-devtools-mcp --version")
    guest.succeed("getent group agent")
    guest.succeed('test "$(stat -c %U:%G /home/agent)" = agent:agent')
    guest.wait_for_unit("home-manager-aditya.sharma.service")
    guest.succeed("getent passwd aditya.sharma | grep -q '/bin/zsh$'")
    guest.succeed("test -L /home/aditya.sharma/.zshrc")
  '';
}
