open Utils.Syntax

let root = Fpath.v "benchs/btree"

let problems_root = Fpath.(root / "btree" / "native")

let files () =
  Bos.OS.Dir.fold_contents ~dotfiles:false ~elements:`Files ~traverse:`Any
    (fun name acc ->
      if not (Fpath.has_ext ".wat" name) then acc else name :: acc )
    [] problems_root

let runs tool timeout output_dir max_tests =
  let+ files = files () in
  let output_chan =
    Fpath.(output_dir / "results") |> Fpath.to_string |> open_out
  in
  let fmt = Format.formatter_of_out_channel output_chan in
  let pp x = Fmt.pf fmt x in
  let files = List.sort Fpath.compare files in
  let len = List.length files in
  let results = ref Runs.empty in
  List.iteri
    (fun i file ->
      let i = succ i in
      if i <= max_tests then begin
        Logs.app (fun m -> m "%a" (Run.pp_header (min len max_tests)) (i, file));
        pp "%a@\n  @[<v>" (Run.pp_header (min len max_tests)) (i, file);
        let result =
          Tool.fork_and_run_on_file ~i ~fmt ~output_dir ~file ~tool ~timeout
          |> Utils.ok_or_fail
        in
        let result = { Run.i; file; res = result } in
        results := Runs.add result !results;
        Logs.app (fun m -> m "  %a@]" Runs.pp_quick_results !results);
        pp "%a@]@\n%!" Runs.pp_quick_results !results
      end )
    files;
  !results

let run tool timeout max_tests =
  let* () =
    match Bos.OS.Env.var Tool.tool_path_env_var_name with
    | None -> Tool.check_if_available tool
    | Some _ -> Ok ()
  in
  let t = Unix.localtime @@ Unix.gettimeofday () in
  let reference_name = Tool.to_reference_name tool in
  let filename =
    Fmt.str "results-testcomp-%s-%d-%02d-%02d_%02dh%02dm%02ds/" reference_name
      (1900 + t.tm_year) (1 + t.tm_mon) t.tm_mday t.tm_hour t.tm_min t.tm_sec
  in
  let output_dir = Fpath.v filename in
  let _ : bool =
    Bos.OS.Dir.create ~path:true ~mode:0o755 output_dir |> Utils.ok_or_fail
  in
  let runs = runs tool timeout output_dir max_tests in
  let runs = Utils.ok_or_fail runs in
  let _workers = Tool.get_number_of_workers tool in
  (* notify_finished runs timeout reference_name output_dir workers; *)
  Utils.gen_full_report runs output_dir reference_name
