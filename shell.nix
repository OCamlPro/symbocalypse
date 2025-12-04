{ pkgs ? import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  }) {}
}:

let
  extunix = pkgs.ocamlPackages.buildDunePackage (finalAttrs: {
    pname = "extunix";
    version = "0.4.4";

    src = pkgs.fetchFromGitHub {
      owner = "ygrek";
      repo = "extunix";
      tag = "v${finalAttrs.version}";
      hash = "sha256-7wJDGv19etkDHRwwQ+WONtJswxNMjr2Q2Vhis4WgFek=";
    };

    postPatch = ''
      substituteInPlace src/dune --replace 'libraries unix bigarray bytes' 'libraries unix bigarray'
    '';

    nativeBuildInputs = with pkgs.ocamlPackages; [
      dune-configurator
      ppxlib
    ];

    propagatedBuildInputs = with pkgs.ocamlPackages; [
      dune-configurator
      gnuplot
      ppxlib
    ];

  });
in

pkgs.mkShell {
  nativeBuildInputs = with pkgs.ocamlPackages; [
    dune_3
    findlib
    merlin
    ocaml
    ocamlformat
    ocp-browser
  ];
  propagatedBuildInputs = with pkgs.ocamlPackages; [
    cohttp-lwt-unix
    extunix
    rusage
    smtml
    tyxml
    yaml
  ];
}
