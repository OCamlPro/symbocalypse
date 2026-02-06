open Utils.Syntax

type t =
  | Owi of
      { mode : string
      ; optimisation_level : int
      ; workers : int
      ; solver : Smtml.Solver_type.t
      ; exploration_strategy : string
      ; fail_on_assertion_only : bool
      ; entry_point : string option
      ; bench : bool
      }
  | Klee
  | Symbiotic
  | Soteria

let to_short_name = function
  | Owi _ -> "owi"
  | Klee -> "klee"
  | Symbiotic -> "symbiotic"
  | Soteria -> "soteria"

let to_reference_name = function
  | Owi { workers; optimisation_level; solver; exploration_strategy; bench = _ }
    ->
    Fmt.str "owi_w%d_O%d_s%a_%s" workers optimisation_level Smtml.Solver_type.pp
      solver exploration_strategy
  | Klee -> "klee"
  | Symbiotic -> "symbiotic"
  | Soteria -> "soteria"

let get_number_of_workers = function
  | Owi { workers; _ } -> workers
  | Klee | Symbiotic | Soteria -> 1

let mk_owi ~mode ~bench ~exploration_strategy ~optimisation_level ~solver
  ~workers ~fail_on_assertion_only ~entry_point =
  Owi
    { mode
    ; bench
    ; workers
    ; optimisation_level
    ; solver
    ; exploration_strategy
    ; fail_on_assertion_only
    ; entry_point
    }

let mk_klee () = Klee

let mk_soteria () = Soteria

let mk_symbiotic () = Symbiotic

let tool_path_env_var_name = "S_TOOL_PATH"

let get_path =
  match Bos.OS.Env.var tool_path_env_var_name with
  | Some v -> fun _tool -> v
  | None -> (
    function
    | Owi _ -> "_build/install/default/bin/owi"
    | Klee -> "tools/klee/bin/klee"
    | Symbiotic -> "tools/symbiotic/bin/symbiotic"
    | Soteria -> "_build/install/default/bin/soteria-c" )

let help_install = function
  | Owi _ ->
    Logs.err (fun m ->
      m
        "Make sure you cloned the submodule with: git submodule update --init \
         --depth 1 tools/owi" );
    Logs.err (fun m ->
      m "Then run: dune build @install -p symbocalypse,owi --profile release" )
  | Klee ->
    Logs.err (fun m ->
      m
        "Make sure you cloned the submodule with: git submodule update --init \
         --depth 1 tools/klee" )
  | Symbiotic ->
    Logs.err (fun m ->
      m
        "Make sure you cloned the submodule with: git submodule update --init \
         --depth 1 tools/symbiotic" )
  | Soteria ->
    Logs.err (fun m ->
      m
        "Make sure you cloned the submodule with: git submodule update --init \
         --depth 1 tools/soteria" );
    Logs.err (fun m ->
      m
        "Then run: dune build @install -p symbocalypse,soteria-c --profile \
         release" )

let is_installed tool =
  let path_to_tool = get_path tool |> Fpath.v in
  match Bos.OS.File.exists path_to_tool with
  | Ok true -> true
  | Ok false | Error _ -> false

let check_if_available tool =
  if is_installed tool then Ok ()
  else
    let path = get_path tool in
    Logs.err (fun m -> m "Could not find the expected file at `%s`." path);
    help_install tool;
    Fmt.error_msg
      "If you want to override the path, you can set the environment variable \
       %s."
      tool_path_env_var_name

exception Sigchld

let kill_klee_descendants () =
  let _ : int = Fmt.kstr Sys.command "pkill klee" in
  ()

let wait_pid ~pid ~timeout ~tool ~dst_stderr =
  let did_timeout = ref false in
  let start_time = Unix.gettimeofday () in
  begin try
    Sys.set_signal Sys.sigchld (Signal_handle (fun (_ : int) -> raise Sigchld));
    Unix.sleepf timeout;
    did_timeout := true;
    (* we kill the process group id (pgid) which should be equal to pid *)
    Unix.kill ~-pid 9;
    Sys.set_signal Sys.sigchld Signal_default
  with Sigchld -> ()
  end;
  Sys.set_signal Sys.sigchld Signal_default;
  let ( waited_pid
      , status
      , { ExtUnix.Specific.ru_utime = utime
        ; ru_stime = stime
        ; ru_maxrss = maxrss
        } ) =
    ExtUnix.Specific.wait4 [] ~-pid
  in
  (* Because symbiotic is leaking klee processes *)
  kill_klee_descendants ();
  let end_time = Unix.gettimeofday () in
  assert (waited_pid = pid);

  let clock = end_time -. start_time in

  (* Sometimes the clock goes a little bit above the allowed timeout... *)
  let clock = min clock timeout in
  let rusage = { Timings.clock; utime; stime; maxrss } in

  if !did_timeout || Float.equal clock timeout then Run_result.Timeout rusage
  else
    match status with
    | WEXITED code -> begin
      match tool with
      | Owi _ ->
        if code = 0 then Nothing rusage
        else if code = 13 then Reached rusage
        else Other (rusage, code)
      | Soteria ->
        if code = 0 then Nothing rusage
        else if code = 13 then Reached rusage
        else Other (rusage, code)
      | Klee ->
        if code = 0 then begin
          let chan = open_in (Fpath.to_string dst_stderr) in
          let has_found_error = ref false in
          begin try
            while true do
              let line = input_line chan in
              match
                String.split_on_char ' ' line |> List.filter (fun s -> s <> "")
              with
              | [ "KLEE:"; "ERROR:"; _location; "ASSERTION"; "FAIL:"; "0" ] ->
                has_found_error := true;
                raise Exit
              | _line -> ()
            done
          with End_of_file | Exit -> ()
          end;
          close_in chan;
          if !has_found_error then Reached rusage else Nothing rusage
        end
        else Other (rusage, code)
      | Symbiotic ->
        if code = 0 then begin
          match Bos.OS.File.read dst_stderr with
          | Error (`Msg err) -> failwith err
          | Ok data -> (
            let error = Astring.String.find_sub ~sub:"Found ERROR!" data in
            match error with Some _ -> Reached rusage | None -> Nothing rusage )
        end
        else Other (rusage, code)
    end
    | WSIGNALED n -> Signaled (rusage, n)
    | WSTOPPED n -> Stopped (rusage, n)

let execvp ~output_dir tool file timeout =
  let output_dir = Fpath.(output_dir / to_short_name tool) |> Fpath.to_string in
  let file = Fpath.to_string file in
  let timeout = string_of_int timeout in
  let path_to_tool = get_path tool in
  let tool_option cond value = if cond then [ value ] else [] in
  let bin, args =
    match tool with
    | Owi opts ->
      ( path_to_tool
      , [ path_to_tool
        ; opts.mode
        ; "--unsafe"
        ; Fmt.str "-w%d" opts.workers
        ; "--workspace"
        ; output_dir
        ; "--exploration"
        ; opts.exploration_strategy
        ; "-q"
        ]
        @ tool_option opts.bench "--bench"
        @ tool_option opts.fail_on_assertion_only "--fail-on-assertion-only"
        @ tool_option
            (opts.mode = "c" || opts.mode = "c++")
            (Fmt.str "-O%d" opts.optimisation_level)
        @ ( match opts.entry_point with
          | Some ep -> [ "--entry-point"; ep ]
          | None -> [] )
        @ [ file ] )
    | Klee ->
      ( path_to_tool
      , [ path_to_tool
        ; "--error-only"
        ; "--max-time"
        ; timeout
        ; "--max-walltime"
        ; timeout
        ; file
        ] )
    | Symbiotic ->
      ( path_to_tool
      , [ path_to_tool
        ; "--test-comp"
        ; Fmt.str "--timeout=%s" timeout
        ; "--prp=testcomp/sv-benchmarks/c/properties/coverage-error-call.prp"
        ; file
        ] )
    | Soteria ->
      ( path_to_tool
      , [ path_to_tool
        ; "exec"
        ; file
        ; "--testcomp"
        ; "--step-fuel"
        ; "1500"
        ; "--branch-fuel"
        ; "infinite"
        ; "--alloc-cannot-fail"
        ; "--ignore-ub"
        ] )
  in
  Logs.app (fun m -> m "  Executing: %s %a" bin Fmt.(Dump.list string) args);
  let args = Array.of_list args in
  Unix.execvp bin args

let dup ~src ~dst =
  let new_file =
    Unix.openfile (Fpath.to_string dst) [ O_CREAT; O_WRONLY ] 0o666
  in
  Unix.dup2 new_file src;
  Unix.close new_file

let fork_and_run_on_file ~i ~fmt ~output_dir ~file ~tool ~timeout =
  let output_dir = Fpath.(output_dir / string_of_int i) in
  let+ (_existed : bool) =
    Bos.OS.Dir.create ~path:true ~mode:0o755 output_dir
  in
  let dst_stderr = Fpath.(output_dir / "stderr") in
  let result =
    let rec loop retries =
      let pid = Unix.fork () in
      if pid = 0 then begin
        ExtUnix.Specific.setpgid 0 0;
        dup ~dst:Fpath.(output_dir / "stdout") ~src:Unix.stdout;
        dup ~dst:dst_stderr ~src:Unix.stderr;
        execvp ~output_dir tool file (int_of_float timeout)
      end
      else begin
        match wait_pid ~pid ~timeout ~tool ~dst_stderr with
        | (Signaled _ | Stopped _) as result ->
          if retries = 0 then result else loop (pred retries)
        | result -> result
      end
    in

    loop 10
  in
  Logs.app (fun m -> m "  %a" Run_result.pp result);
  Fmt.pf fmt "%a@\n" Run_result.pp result;
  result
