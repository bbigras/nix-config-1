let
  pkgs = import ./nix/nixpkgs.nix {};

  mkGceImage = configuration: system:
    let
      nixos = import ./nix/nixos.nix;
      eval = (nixos { inherit configuration system; });
    in eval.config.system.build.googleComputeImage;
  mkSystem = configuration: system:
    let
      nixos = import ./nix/nixos.nix;
      eval = (nixos { inherit configuration system; });
    in eval.system;

  systems = {
    abel = mkSystem ./systems/abel.nix "x86_64-linux";
    bohr = mkSystem ./systems/bohr.nix "aarch64-linux";
    camus = mkSystem ./systems/camus.nix "aarch64-linux";
    cantor = mkSystem ./systems/cantor.nix "x86_64-linux";
    foucault = mkSystem ./systems/foucault.nix "x86_64-linux";
    peano = mkSystem ./systems/peano.nix "x86_64-linux";
  };

  gceImages = {
    sartre = mkGceImage ./systems/sartre.nix "x86_64-linux";
  };
in
{
  inherit pkgs;
  x86_64 = with systems; [ abel cantor foucault peano ];
  aarch64 = with systems; [ bohr camus ];
} // systems // gceImages
