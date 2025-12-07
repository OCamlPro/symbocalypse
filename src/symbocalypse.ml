open Cmdliner
open Term.Syntax

(* Helpers *)

let existing_file_conv =
  let parse s =
    match Fpath.of_string s with
    | Error _ as e -> e
    | Ok path -> begin
      match Bos.OS.File.exists path with
      | Ok true -> Ok path
      | Ok false -> Fmt.error_msg "no file '%a'" Fpath.pp path
      | Error _ as e -> e
    end
  in
  Arg.conv (parse, Fpath.pp)

let solver_conv = Arg.conv (Smtml.Solver_type.of_string, Smtml.Solver_type.pp)

(* Common options *)

let copts_t = Term.(const [])

let sdocs = Manpage.s_common_options

let shared_man = [ `S Manpage.s_bugs; `P "Email them to <leo@ocaml.pro>." ]

let version = Cmd_version.symbocalypse_version ()

let log_level =
  let env = Cmd.Env.info "SYMBOCALYPSE_VERBOSITY" in
  Logs_cli.level ~env ~docs:sdocs ()

(* Common terms *)

let owi =
  let+ exploration_strategy =
    let exploration_conv =
      let of_string s =
        match String.lowercase_ascii s with
        | ("fifo" | "lifo" | "random" | "smart") as s -> Ok s
        | _ ->
          Fmt.error_msg {|Expected "fifo", "lifo" or "random" but got "%s"|} s
      in
      Arg.conv (of_string, Fmt.string)
    in
    let doc = {|exploration strategy to use ("fifo", "lifo" or "random")|} in
    Arg.(value & opt exploration_conv "fifo" & info [ "exploration" ] ~doc)
  and+ optimisation_level =
    let doc = "specify which optimization level to use" in
    Arg.(value & opt int 1 & info [ "O" ] ~doc)
  and+ solver =
    let docv = Arg.conv_docv solver_conv in
    let doc =
      let pp_bold_solver fmt ty =
        Fmt.pf fmt "$(b,%a)" Smtml.Solver_type.pp ty
      in
      let supported_solvers = Smtml.Solver_dispatcher.supported_solvers in
      Fmt.str
        "SMT solver to use. $(i,%s) must be one of the %d available solvers: %a"
        docv
        (List.length supported_solvers)
        (Fmt.list ~sep:Fmt.comma pp_bold_solver)
        supported_solvers
    in
    Arg.(
      value
      & opt solver_conv Smtml.Solver_type.Z3_solver
      & info [ "solver"; "s" ] ~doc ~docv )
  and+ workers =
    let doc =
      "number of workers for symbolic execution. Defaults to the number of \
       physical cores."
    in
    Arg.(
      value
      & opt int Processor.Query.core_count
      & info [ "workers"; "w" ] ~doc ~absent:"n" )
  in
  Tool.mk_owi ~workers ~optimisation_level ~solver ~exploration_strategy

let result_file =
  let doc = "result file" in
  Arg.(
    required & pos 0 (some existing_file_conv) None (info [] ~doc ~docv:"FILE") )

let result_file_two =
  let doc = "result files" in
  let+ file1 =
    Arg.(
      required
      & pos 0 (some existing_file_conv) None (info [] ~doc ~docv:"FILE1") )
  and+ file2 =
    Arg.(
      required
      & pos 1 (some existing_file_conv) None (info [] ~doc ~docv:"FILE2") )
  in
  (file1, file2)

let setup_log =
  let+ log_level
  and+ style_renderer = Fmt_cli.style_renderer ~docs:sdocs () in
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level log_level;
  Logs.set_reporter (Logs.format_reporter ())

let timeout = Arg.(value & pos 0 float 30. & info [] ~docv:"timeout")

(* symbocalypse diff *)
let diff_info =
  let doc = "Compare two benchmarks results" in
  let man = shared_man in
  Cmd.info "diff" ~version ~doc ~sdocs ~man

let diff_cmd =
  let+ () = setup_log
  and+ file1, file2 = result_file_two in
  Cmd_diff.run file1 file2

(* symbocalypse report *)
let report_info =
  let doc = "Generate a report from existing benchmarks results" in
  let man = shared_man in
  Cmd.info "report" ~version ~doc ~sdocs ~man

let report_cmd =
  let+ () = setup_log
  and+ result_file in
  Cmd_report.run result_file

(* symbocalypse testcomp klee *)
let testcomp_klee_info =
  let doc = "KLEE engine" in
  let man = shared_man in
  Cmd.info "klee" ~version ~doc ~sdocs ~man

let testcomp_klee_cmd =
  let+ () = setup_log
  and+ timeout in
  let tool = Tool.mk_klee () in
  Cmd_testcomp.run tool timeout

(* symbocalypse testcomp owi *)
let testcomp_owi_info =
  let doc = "Owi engine" in
  let man = shared_man in
  Cmd.info "owi" ~version ~doc ~sdocs ~man

let testcomp_owi_cmd =
  let+ () = setup_log
  and+ timeout
  and+ owi in
  Cmd_testcomp.run owi timeout

(* symbocalypse testcomp soteria *)
let testcomp_soteria_info =
  let doc = "Soteria engine" in
  let man = shared_man in
  Cmd.info "soteria" ~version ~doc ~sdocs ~man

let testcomp_soteria_cmd =
  let+ () = setup_log
  and+ timeout in
  let tool = Tool.mk_soteria () in
  Cmd_testcomp.run tool timeout

(* symbocalypse testcomp symbiotic *)
let testcomp_symbiotic_info =
  let doc = "Symbiotic engine" in
  let man = shared_man in
  Cmd.info "symbiotic" ~version ~doc ~sdocs ~man

let testcomp_symbiotic_cmd =
  let+ () = setup_log
  and+ timeout in
  let tool = Tool.mk_symbiotic () in
  Cmd_testcomp.run tool timeout

(* symbocalypse testcomp *)
let testcomp_info =
  let doc = "Run Test-Comp" in
  let man = shared_man in
  Cmd.info "testcomp" ~version ~doc ~sdocs ~man

let testcomp_cmd =
  Cmd.group testcomp_info
    [ Cmd.v testcomp_klee_info testcomp_klee_cmd
    ; Cmd.v testcomp_owi_info testcomp_owi_cmd
    ; Cmd.v testcomp_soteria_info testcomp_soteria_cmd
    ; Cmd.v testcomp_symbiotic_info testcomp_symbiotic_cmd
    ]

(* symbocalypse version *)
let version_info =
  let doc = "Print some version informations" in
  let man = shared_man in
  Cmd.info "version" ~version ~doc ~sdocs ~man

let version_cmd =
  let+ () = setup_log
  and+ () = Term.const () in
  Cmd_version.cmd ()

(* symbocalypse *)
let cli =
  let info =
    let doc = "Symbocalypse benchmarking tool" in
    let man = shared_man in
    Cmd.info "symbocalypse" ~version ~doc ~sdocs ~man
  in
  let default =
    Term.(ret (const (fun (_ : _ list) -> `Help (`Plain, None)) $ copts_t))
  in
  Cmd.group info ~default
    [ Cmd.v diff_info diff_cmd
    ; Cmd.v report_info report_cmd
    ; testcomp_cmd
    ; Cmd.v version_info version_cmd
    ]

let exit_code =
  let open Cmd.Exit in
  match Cmd.eval_value cli with
  | Ok (`Help | `Version | `Ok (Ok ())) -> ok
  | Ok (`Ok (Error _e)) ->
    Logs.err (fun m -> m ":-(");
    121
  | Error `Term -> 122
  | Error `Parse -> cli_error
  | Error `Exn -> internal_error

let () = exit exit_code
