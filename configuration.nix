{ self, pkgs, config, lib, modulesPath, ... }:
let
  inherit (lib) mkIf;
  inherit (config.services) jupyterhub nginx;
  inherit (config) networking;
  inherit (pkgs) openssl python311 nodejs symlinkJoin;

  python3 = python311;

  pythonEnv = python3.withPackages ({ pipx, pip, ... }: [ pipx pip ]);
in
{

  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  nix = {
    nixPath = [
      "nixpkgs=${self.inputs.nixpkgs}"
      "nixos-config=${./configuration.nix}"
    ];
  };

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
    manageHostName = true;
  };

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

  environment.systemPackages = [ (python3.withPackages (p: with p; [ jupyterhub jupyterlab ])) ];

  services.jupyterhub = {
    enable = true;

    host = "127.0.0.1";

    jupyterlabEnv = python3.withPackages (p: with p; [ jupyterhub jupyterlab ]);
    jupyterhubEnv = python3.withPackages
      (p: with p; [ jupyterhub jupyterhub-systemdspawner ]);

    extraConfig = ''
      c.SystemdSpawner.isolate_tmp = True
      c.SystemdSpawner.isolate_devices = True
      c.SystemdSpawner.readonly_paths = ['/']
      c.SystemdSpawner.readwrite_paths = [ '/home/{USERNAME}', '/nix/store', '/nix/var/nix/profiles/per-user/{USERNAME}' ]
      c.SystemdSpawner.disable_user_sudo = True
      c.SystemdSpawner.unit_extra_properties = { 'PrivateMounts': True }
      c.SystemdSpawner.extra_paths = [ "${pythonEnv}/bin" ]
    '';
  };

  services.nginx = mkIf jupyterhub.enable ({
    enable = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    preStart = ''
      KEY_FILE="$STATE_DIRECTORY/certs/${networking.fqdn}.key"
      CERT_FILE="$STATE_DIRECTORY/certs/${networking.fqdn}.cert"

      if [[ ! -f "$CERT_FILE" ]];
      then
          mkdir -p "$STATE_DIRECTORY/certs"
          ${openssl}/bin/openssl req \
                                 -newkey rsa:2048 -nodes -keyout "$KEY_FILE" \
                                 -x509 -out "$CERT_FILE" \
                                 -subj "/CN=${networking.fqdn}"
      fi
    '';

    virtualHosts."${networking.fqdn}" = {
      forceSSL = true;

      sslCertificateKey = "/var/lib/nginx/certs/${networking.fqdn}.key";
      sslCertificate = "/var/lib/nginx/certs/${networking.fqdn}.cert";

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString jupyterhub.port}";
        proxyWebsockets = true;

        extraConfig = ''
          proxy_set_header X-Scheme $scheme;
          proxy_buffering off;
        '';
      };

      locations."~ /.well-known" = {
        extraConfig = ''
          allow all;
        '';
      };
    };
  });

  networking.firewall = mkIf nginx.enable { allowedTCPPorts = [ 80 443 ]; };

  systemd.services.nginx = mkIf nginx.enable {
    serviceConfig.StateDirectory = "nginx";
    serviceConfig.StateDirectoryMode = "0750";
  };

  systemd.suppressedSystemUnits = [
    "dev-mqueue.mount"
    "sys-kernel-debug.mount"
    "sys-fs-fuse-connections.mount"
  ];

  users.mutableUsers = false;
  users.users.root = {
    hashedPassword = "*";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDG+CTN3wwIiErQBwNDUUEx0VNromjEsDFp8N6y5x2U/nwOE05jC9NjKwf8MyM8f0mDqJfLAcfv2+tyQPP08ndtxSDwfCY0wFFcsVraksR84AULpCwJFuRJVV86O/S1Aat9n4iEMATdx/GSMWce1SnOpezanja/b43tliFN7OHfFsPgFKG+ojP9bh+bFu7B4xH8edFgMEbQAUHIqwb3xA00JW5l7h1wx/2QaGc+ucMwPgkxoubVE+O9Anio2Gwnu0nR4akBgEGXbwR5sUzV6DuiMAg/GRSHzeCiPc5NHEC7MOTPrIQh0x+j+triBebCw/ec95FRNlhXIMPiqoZhuGlIBTTm5uO18nZuSZ0cbL2pxDNBVk2ZBB3FNxiJ3JntzleNYk+K4EtFjvT2XBqwUNTvsuxJe6bvM0dvFvY9/tMjJJGpsCsxR9PWdUtHQO93JsQK1gld2lUA1c+JAdMMy13q4HfKe8yQGDw3D0qXYoAvy52RZlrXcwsOsHC1UqXZdaZaZ5xLtviLrtSTXwqg/3edq4uuuouezNzOUeY3JQ3wIOCahYs/wsQ+x9M2xWBzM6ZUfqtI8J0HwtRAm+9JfMkxYPEiLvoC8f8C4YZPgWg5JUlSu0f2/+i0dV4bddxPdjEGIdIp6j2DC8WK6CrR6Ve84FJr3UP4AF6vSq4MfyD54Q== cardno:11 467 797"
    ];
  };

  users.users.grenewode = {
    isNormalUser = true;
    hashedPassword =
      "$y$j9T$JvhWo6iJguPWNuFcjCv300$pIEkwdqQ82A3N54k4NWl5wNcktIo5VaQd7bfwr2G.e0";
  };

  system.stateVersion = "23.05";
}
