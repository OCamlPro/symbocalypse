let root = Fpath.v "benchs/btree"

let problems_root = Fpath.(root / "btree" / "native")

let files () =
  Bos.OS.Dir.fold_contents ~dotfiles:false ~elements:`Files ~traverse:`Any
    (fun name acc ->
      if not (Fpath.has_ext ".wat" name) then acc else name :: acc )
    [] problems_root

let run tool timeout max_test =
  let files = Utils.ok_or_fail (files ()) in
  Bench.run tool timeout max_test files
