{ self, pkgs, config, lib, modulesPath, ... }: {

  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking = {
    hostName = "jupyter";
    domain = "intra.lair.onl";
  };

  system.autoUpgrade = {
    enable = true;
    flake = "github:grenewode/jupyterhub-deploy";
    allowReboot = true;
    rebootWindow = {
      lower = "01:00";
      upper = "05:00";
    };
  };

  proxmoxLXC = { manageNetwork = true; };

  services.jupyterhub = {
    enable = true;

    jupyterlabEnv = pkgs.python3.withPackages
      (p: with p; [ jupyterhub jupyterlab jupyterlab-lsp python-lsp-server ]);

  };

  users.mutableUsers = false;
  users.users.root = {
    hashedPassword = "*";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDG+CTN3wwIiErQBwNDUUEx0VNromjEsDFp8N6y5x2U/nwOE05jC9NjKwf8MyM8f0mDqJfLAcfv2+tyQPP08ndtxSDwfCY0wFFcsVraksR84AULpCwJFuRJVV86O/S1Aat9n4iEMATdx/GSMWce1SnOpezanja/b43tliFN7OHfFsPgFKG+ojP9bh+bFu7B4xH8edFgMEbQAUHIqwb3xA00JW5l7h1wx/2QaGc+ucMwPgkxoubVE+O9Anio2Gwnu0nR4akBgEGXbwR5sUzV6DuiMAg/GRSHzeCiPc5NHEC7MOTPrIQh0x+j+triBebCw/ec95FRNlhXIMPiqoZhuGlIBTTm5uO18nZuSZ0cbL2pxDNBVk2ZBB3FNxiJ3JntzleNYk+K4EtFjvT2XBqwUNTvsuxJe6bvM0dvFvY9/tMjJJGpsCsxR9PWdUtHQO93JsQK1gld2lUA1c+JAdMMy13q4HfKe8yQGDw3D0qXYoAvy52RZlrXcwsOsHC1UqXZdaZaZ5xLtviLrtSTXwqg/3edq4uuuouezNzOUeY3JQ3wIOCahYs/wsQ+x9M2xWBzM6ZUfqtI8J0HwtRAm+9JfMkxYPEiLvoC8f8C4YZPgWg5JUlSu0f2/+i0dV4bddxPdjEGIdIp6j2DC8WK6CrR6Ve84FJr3UP4AF6vSq4MfyD54Q== cardno:11 467 797"
    ];
  };

  system.stateVersion = "22.11";
}
