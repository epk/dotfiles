{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      # Keep the inner quotes. ssh_config requires quotes around paths with spaces.
      IdentityAgent = ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
    };
  };
}
