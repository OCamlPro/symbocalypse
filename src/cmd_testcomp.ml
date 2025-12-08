module Unix = struct
  include Unix
  include Bos.OS.U
end

let ( let* ) o f = match o with Ok v -> f v | Error _ as e -> e

let ( let+ ) o f = match o with Ok v -> Ok (f v) | Error _ as e -> e

let ok_or_fail = function
  | Error (`Msg m) ->
    Fmt.epr "ERROR: %s@\n" m;
    exit 1
  | Error (`Unix e) ->
    Fmt.epr "ERROR: %s@\n" (Unix.error_message e);
    exit 1
  | Ok x -> x

let object_field (yml : Yaml.value) (field : string) =
  match yml with
  | `O l -> (
    List.assoc_opt field l |> function
    | None -> Fmt.error_msg "missing field %s" field
    | Some v -> Ok v )
  | _ -> Fmt.error_msg "malformed yaml"

let array_map f (yml : Yaml.value) =
  match yml with
  | `A l -> Ok (List.filter_map (fun v -> f v |> Result.to_option) l)
  | _ -> Error (`Msg "malformed yaml")

let property (yml : Yaml.value) =
  let* file = object_field yml "property_file" in
  let* expected = object_field yml "expected_verdict" in
  let* file = Yaml.Util.to_string file in
  let file = Fpath.v file in
  let+ expected = Yaml.Util.to_bool expected in
  (file, expected)

let problem (yml : Yaml.value) dir =
  let* input_file = object_field yml "input_files" in
  let* properties = object_field yml "properties" in
  let* options = object_field yml "options" in
  let* language = object_field options "language" in
  let* language = Yaml.Util.to_string language in
  let* properties = array_map property properties in
  let+ input_file = Yaml.Util.to_string input_file in
  let input_file = Fpath.(dir / input_file) in
  (input_file, properties, language)

let parse_file path =
  let* yml =
    Bos.OS.File.with_ic path
      (fun chan () ->
        let s = In_channel.input_all chan in
        Yaml.of_string s )
      ()
  in
  yml

let problems_root = Fpath.v "benchs/sv-benchmarks/c/"

let is_in_whitelist =
  let tbl = Hashtbl.create 2048 in
  String.split_on_char '\n' Testcomp_whitelist.v
  |> List.iter (function
    | "" -> ()
    | file ->
      let file = Fpath.(problems_root // v file) in
      Hashtbl.replace tbl file () );
  fun file -> Hashtbl.mem tbl file

let is_valid_problem language properties =
  language = "C"
  && List.exists
       (function
         | file, false -> String.equal "unreach-call.prp" (Fpath.filename file)
         | _ -> false )
       properties

let files () =
  let* res =
    Bos.OS.Dir.fold_contents ~dotfiles:false ~elements:`Files ~traverse:`Any
      (fun name acc ->
        let* acc in
        if not (Fpath.has_ext ".yml" name && is_in_whitelist name) then Ok acc
        else
          let* yml = parse_file name in
          let+ input_file, properties, language =
            let dir = fst @@ Fpath.split_base name in
            problem yml dir
          in
          if is_valid_problem language properties then input_file :: acc
          else acc )
      (Ok []) problems_root
  in
  res

let runs tool timeout output_dir =
  let+ files = files () in
  let output_chan =
    Fpath.(output_dir / "results") |> Fpath.to_string |> open_out
  in
  let fmt = Format.formatter_of_out_channel output_chan in
  let pp x = Fmt.pf fmt x in
  let files = List.sort Fpath.compare files in
  let len = List.length files in
  let results = ref Runs.empty in
  let limit = 10_000 in
  List.iteri
    (fun i file ->
      let i = succ i in
      if i < limit + 1 then begin
        Logs.app (fun m -> m "%a" (Run.pp_header (min len limit)) (i, file));
        pp "%a@\n  @[<v>" (Run.pp_header (min len limit)) (i, file);
        let result =
          Tool.fork_and_run_on_file ~i ~fmt ~output_dir ~file ~tool ~timeout
          |> ok_or_fail
        in
        let result = { Run.i; file; res = result } in
        results := Runs.add result !results;
        Logs.app (fun m -> m "  %a@]" Runs.pp_quick_results !results);
        pp "%a@]@\n%!" Runs.pp_quick_results !results
      end )
    files;
  !results

let notify_finished runs timeout reference_name output_dir =
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
       Time stats (in seconds):@\n\
       @\n\
       %a@\n\
       @\n\
       Memory stats (in MB):@\n\
       @\n\
       %a@."
      reference_name timeout Fpath.pp output_dir Runs.pp_table_results runs
      Runs.pp_table_statistics runs Runs.pp_table_memory runs
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

let run tool timeout =
  let* () = Tool.check_if_available tool in
  let t = Unix.localtime @@ Unix.gettimeofday () in
  let reference_name = Tool.to_reference_name tool in
  let filename =
    Fmt.str "results-testcomp-%s-%d-%02d-%02d_%02dh%02dm%02ds/" reference_name
      (1900 + t.tm_year) (1 + t.tm_mon) t.tm_mday t.tm_hour t.tm_min t.tm_sec
  in
  let output_dir = Fpath.v filename in
  let _ : bool =
    Bos.OS.Dir.create ~path:true ~mode:0o755 output_dir |> ok_or_fail
  in
  let runs = runs tool timeout output_dir in
  let runs = ok_or_fail runs in
  notify_finished runs timeout reference_name output_dir;
  Gen.full_report runs output_dir reference_name
