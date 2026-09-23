{
  description = "CHANGEME";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    set-and-setting = {
      url = "github:pr0d1r2/set-and-setting";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };

    nix-dev-shell-agentic = {
      url = "github:pr0d1r2/nix-dev-shell-agentic";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-lock.follows = "nixpkgs-lock";
        nix-cavekit.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
        nix-cavemem.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      };
    };
    nix-lefthook-bats-unit = {
      url = "github:pr0d1r2/nix-lefthook-bats-unit";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      set-and-setting,
      ...
    }:
    set-and-setting.lib.mkConsumerFlake {
      inherit self nixpkgs set-and-setting;
      fragments = [
        "base"
        "nix"
        "shell"
        "ascii"
        "markdown"
        "yaml"
      ];
      extraPackages = pkgs: {
        default = pkgs.writeShellApplication {
          name = "lefthook-nix-flake-lock-budget";
          runtimeInputs = [ pkgs.jq ];
          text = builtins.readFile ./lefthook-nix-flake-lock-budget.sh;
        };
      };
      src = ./.;
    };
}
