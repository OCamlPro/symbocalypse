module Unix = struct
  include Unix
  include Bos.OS.U
end

open Utils.Syntax

let runs tool timeout output_dir max_tests files =
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

let notify_finished runs timeout reference_name output_dir workers =
  let open Cohttp in
  let open Cohttp_lwt_unix in
  let headers =
    let headers = Header.init () in
    Header.add_list headers
      [ ("Content-type", "application/json"); ("User-Agent", "Owibot/1.1") ]
  in
  let send url body =
    let body = Cohttp_lwt.Body.of_string (Yojson.to_string body) in
    Client.post ~body ~headers url
  in
  let head () =
    let open Bos in
    let cmd = Cmd.(v "git" % "rev-parse" % "--short" % "HEAD") in
    let output = OS.Cmd.run_out ~err:OS.Cmd.err_run_out cmd in
    match OS.Cmd.out_string ~trim:true output with
    | Ok (stdout, (_, `Exited 0)) -> stdout
    | Error (`Msg err) ->
      Fmt.epr "ERROR: %s@." err;
      "unknown"
    | Ok (stdout, (_, (`Exited _ | `Signaled _))) ->
      Fmt.epr "%s@\nWARN: Unable to fetch git HEAD@." stdout;
      "unknown"
  in
  let text =
    Fmt.str
      "@[<v>Using:@;\
       - Tool: `%s`@;\
       - Timeout: `%F`@;\
       - Output dir: `%a`@]@\n\
       @\n\
       Results:@\n\
       @\n\
       %a@\n\
       @\n\
       Wall clock stats (in seconds):@\n\
       @\n\
       %a@\n\
       @\n\
       User time stats (in seconds):@\n\
       @\n\
       %a@\n\
       @\n\
       System time stats (in seconds):@\n\
       @\n\
       %a@\n\
       @\n\
       Parallelism stats (ratio of parallelism / wall clock) (percentage is \
       efficiency related to number of workers)(runs < 1s filtered out) :@\n\
       @\n\
       %a@\n\
       @\n\
       Memory stats (in MB):@\n\
       @\n\
       %a@."
      reference_name timeout Fpath.pp output_dir Runs.pp_table_results runs
      Runs.pp_table_wall_clock runs Runs.pp_table_user_time runs
      Runs.pp_table_system_time runs
      (Runs.pp_table_parallelism_ratio ~workers)
      runs Runs.pp_table_memory runs
  in
  (* Notify on `ZULIP_WEBHOOK` *)
  match Bos.OS.Env.var "ZULIP_WEBHOOK" with
  | None -> Fmt.epr "%s" text
  | Some url ->
    let url = Uri.of_string url in
    let title =
      Fmt.str "Benchmark results (commit hash=%s) :octopus:" (head ())
    in
    let body =
      (* Using Yojson just to ensure we're sending correct json *)
      `Assoc
        [ ( "blocks"
          , `List
              [ `Assoc
                  [ ("type", `String "header")
                  ; ( "text"
                    , `Assoc
                        [ ("type", `String "plain_text")
                        ; ("text", `String title)
                        ; ("emoji", `Bool true)
                        ] )
                  ]
              ; `Assoc
                  [ ("type", `String "section")
                  ; ( "text"
                    , `Assoc
                        [ ("type", `String "mrkdwn"); ("text", `String text) ]
                    )
                  ]
              ] )
        ]
    in
    let result, _ = Lwt_main.run @@ send url body in
    let status = Response.status result in
    Fmt.epr "Server responded: %s@." (Code.string_of_status status)

let run tool timeout max_tests files =
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
  let runs = runs tool timeout output_dir max_tests files in
  let workers = Tool.get_number_of_workers tool in
  notify_finished runs timeout reference_name output_dir workers;
  Utils.gen_full_report runs output_dir reference_name
