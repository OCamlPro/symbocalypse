let
  pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {};
  ocamlPackages = pkgs.ocamlPackages.overrideScope (self: super: {
    ocaml = (super.ocaml.overrideAttrs {
      doCheck = false;
    }).override {
      #aflSupport = true;
      flambdaSupport = true;
      framePointerSupport = true;
      #spaceTimeSupport = true;
    };
    smtml = super.smtml.overrideAttrs (old: {
      src = fetchGit {
        url = "https://github.com/redianthus/smtml";
        rev = "450c74c632243a3b0d3b9de18717d7431fe4c61b";
      };
    });
  });
  owi = (pkgs.owi.override {
    ocaml-ng.ocamlPackages_5_4 = ocamlPackages;
  }).overrideAttrs (old: {
    src = fetchGit {
      url = "https://github.com/redianthus/owi";
      rev = "079839c64d737e68ff1e7e92b63726ef2dfcff36";
    };
  });
in

pkgs.mkShell {
  dontDetectOcamlConflicts = true;
  nativeBuildInputs = with ocamlPackages; [
    dune_3
    dune-build-info
    findlib
    merlin
    ocaml
    ocamlformat
    ocp-browser
    pkgs.python3 # KLEE
    pkgs.z3 # soteria-c
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
    #
    owi
  ];
}
