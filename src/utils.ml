module Syntax = struct
  let ( let* ) o f = match o with Ok v -> f v | Error _ as e -> e

  let ( let+ ) o f = match o with Ok v -> Ok (f v) | Error _ as e -> e
end

open Syntax

let ok_or_fail = function
  | Error (`Msg m) ->
    Fmt.epr "ERROR: %s@\n" m;
    exit 1
  | Error (`Unix e) ->
    Fmt.epr "ERROR: %s@\n" (Unix.error_message e);
    exit 1
  | Ok x -> x

let gen_full_report runs output_dir reference_name =
  let output_dir = Fpath.(output_dir // v "results-report/") in

  let+ (_existed : bool) =
    Bos.OS.Dir.create ~path:true ~mode:0o755 output_dir
  in

  Html.make runs output_dir reference_name;
  Time_distribution.make runs output_dir reference_name
