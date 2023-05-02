{
  description = "A very basic flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-generators }: rec {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      modules = [ ./configuration.nix ];

      specialArgs = { inherit self; };
    };

    packages.x86_64-linux = {
      default = nixos-generators.nixosGenerate {
        system = "x86_64-linux";

        modules = [ ./configuration.nix ];

        format = "proxmox-lxc";
      };
    };
  };
}
