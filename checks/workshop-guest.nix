# Boot the workshop guest services in a test VM. #26 fixed three startup defects that passed eval and build.
{ self, pkgs }:
pkgs.testers.runNixOSTest {
  name = "workshop-guest";
  node.pkgsReadOnly = false;
  node.specialArgs.workshop = {
    storageDirectory = "/var/lib/workshop";
    administratorKeys = [ ];
    network = {
      interface = "workshop-tap";
      hostAddress = "10.77.0.1";
      guestAddress = "10.77.0.2";
      prefixLength = 30;
    };
    # The test boots a small tool set. paseo and bb wait for a Tailscale login.
    tools = {
      browser.enable = true;
      claudeCode.enable = true;
      codex.enable = true;
      gemini.enable = true;
      antigravity.enable = true;
      amp.enable = false;
      bb.enable = false;
      cua.enable = false;
      omp.enable = false;
      paseo.enable = false;
      pomerado.enable = false;
    };
  };
  node.specialArgs.inputs = self.inputs // {
    inherit self;
  };
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
    guest.wait_for_unit("home-manager-agent.service")
    guest.succeed("grep -q daemon_auto_start /home/agent/.codex/config.toml")
    guest.succeed("test -s /home/agent/.gemini/config/mcp_config.json")
    guest.succeed("getent passwd aditya.sharma | grep -q '/bin/zsh$'")
    guest.succeed("test -L /home/aditya.sharma/.zshrc")
  '';
}
