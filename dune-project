(lang dune 3.17)

(name symbocalypse)

(generate_opam_files true)

(source
 (github OCamlPro/symbocalypse))

(authors "Léo Andrès <contact@ndrs.fr>")

(maintainers "Léo Andrès <contact@ndrs.fr>")

(package
 (allow_empty) ; FIXME: Remove once we add a symbocalypse stanza?
 (name symbocalypse)
 (synopsis "Symbolic Execution benchmarks")
 (description "Symbolic Execution benchmarks")
 (depends
  ocaml
  dune
  bos
  (extunix
   (>= 0.4.4))
  rusage
  smtml
  yaml
  cohttp
  cohttp-lwt-unix
  lwt
  gnuplot
  tyxml))
