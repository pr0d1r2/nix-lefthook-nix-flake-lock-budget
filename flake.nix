{
  description = "Lefthook guard: fail when flake.lock exceeds node-count or file-size budget";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
    nix-dev-shell-agentic = {
      url = "git+https://github.com/pr0d1r2/nix-dev-shell-agentic.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-lefthook-bats-unit = {
      url = "github:pr0d1r2/nix-lefthook-bats-unit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-lefthook-markdownlint-agentic = {
      url = "github:pr0d1r2/nix-lefthook-markdownlint-agentic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-dev-shell-agentic,
      nix-lefthook-markdownlint-agentic,
      ...
    }@inputs:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        default = pkgs.writeShellApplication {
          name = "lefthook-nix-flake-lock-budget";
          runtimeInputs = [ pkgs.jq ];
          text = builtins.readFile ./lefthook-nix-flake-lock-budget.sh;
        };
      });

      devShells = forAllSystems (
        pkgs:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          shells = nix-dev-shell-agentic.lib.mkShells {
            inherit pkgs inputs;
            ciPackages = [
              self.packages.${system}.default
              nix-lefthook-markdownlint-agentic.packages.${system}.default
            ];
            shellHook = builtins.replaceStrings [ "@BATS_LIB_PATH@" ] [ "${shells.batsWithLibs}" ] (
              builtins.readFile ./dev.sh
            );
          };
        in
        shells
      );
    };
}
