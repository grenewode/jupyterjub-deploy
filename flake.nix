{
  description = "A very basic flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";

  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.deploy-rs.url = "github:serokell/deploy-rs";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, nixos-generators, deploy-rs, flake-utils }:
    {
      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        modules = [ ./configuration.nix ];

        specialArgs = { inherit self; };
      };

      deploy.nodes."jupyter.intra.lair.onl" = {

        hostname = "jupyter.intra.lair.onl";
        profiles.system = {
          user = "root";
          sshUser = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.default;
        };
      };

      checks =
        builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy)
          deploy-rs.lib;
    } // (flake-utils.lib.eachSystem [ self.nixosConfigurations.default.config.nixpkgs.hostPlatform.system] (localSystem:
      let
        pkgs = import nixpkgs { inherit localSystem; };
        inherit (pkgs) mkShell deploy-rs;
      in
      {

        devShells.default = mkShell { packages = [ deploy-rs ]; };

        packages.default =
          (nixos-generators.nixosGenerate {
            system = localSystem;

            modules = [ ./configuration.nix ];

            specialArgs = { inherit self; };

            format = "proxmox-lxc";
          }).override {
            fileName = "nixos-23.05-jupyterhub_${self.lastModifiedDate}_amd64";
          };
      }));
}
