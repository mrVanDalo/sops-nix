{
  description = "Integrates sops into nixos";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.nixpkgs-stable.url = "github:NixOS/nixpkgs/release-22.11";
  nixConfig.extra-substituters = ["https://cache.garnix.io"];
  nixConfig.extra-trusted-public-keys = ["cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="];
  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable
  }: let
    systems = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
      "aarch64-linux"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    suffix-version = version: attrs: nixpkgs.lib.mapAttrs' (name: value: nixpkgs.lib.nameValuePair (name + version) value) attrs;
    suffix-stable = suffix-version "-22_11";
  in {
    overlay = final: prev: let
      localPkgs = import ./default.nix {pkgs = final;};
    in {
      inherit (localPkgs) sops-install-secrets sops-init-gpg-key sops-pgp-hook sops-import-keys-hook sops-ssh-to-age;
      # backward compatibility
      inherit (prev) ssh-to-pgp;
    };
    nixosModules.sops = import ./modules/sops;
    homeManagerModules.sops = import ./modules/home-manager/sops.nix;
    nixosModule = self.nixosModules.sops;
    homeManagerModule = self.homeManagerModules.sops;
    packages = forAllSystems (system:
      import ./default.nix {
        pkgs = import nixpkgs {inherit system;};
      });
    checks = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"]
      (system: let
        tests = self.packages.${system}.sops-install-secrets.tests;
        packages-stable = import ./default.nix {
          pkgs = import nixpkgs-stable {inherit system;};
        };
        tests-stable = packages-stable.sops-install-secrets.tests;
      in tests //
         (suffix-stable tests-stable) //
         (suffix-stable packages-stable));

    defaultPackage = forAllSystems (system: self.packages.${system}.sops-init-gpg-key);
    devShell = forAllSystems (
      system:
        nixpkgs.legacyPackages.${system}.callPackage ./shell.nix {}
    );
    devShells = forAllSystems (system: {
      unit-tests = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/unit-tests.nix {};
    });
  };
}
