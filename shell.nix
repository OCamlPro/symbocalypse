let
  pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {};
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_5_4;
in

let
  owiSubShell = import ./tools/owi/shell.nix {} ;
in

pkgs.mkShell {
  dontDetectOcamlConflicts = true;
  inputsFrom = [
    owiSubShell
  ];
  nativeBuildInputs = with ocamlPackages; [
    dune_3
    findlib
    merlin
    ocaml
    ocamlformat
    ocp-browser
    pkgs.python3 # KLEE
  ];
  propagatedBuildInputs = with ocamlPackages; [
    cmdliner
    cohttp-lwt-unix
    extunix
    gnuplot
    logs
    lwt
    processor
    rusage
    smtml
    tyxml
    yaml
  ];
}
