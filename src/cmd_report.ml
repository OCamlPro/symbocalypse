(* TODO: put the tool in the output in order to be able to reprint it, instead of using "unknown_tool" *)
let run result_file =
  let runs = Parse.from_file result_file in
  let output_dir = Fpath.v "./" in
  (* TODO *)
  let timeout = 30. in
  let workers = 8 in
  let reference_name = "owi" in
  let old_output_dir = output_dir in
  Bench.notify_finished runs timeout reference_name old_output_dir
    workers;
  Utils.gen_full_report runs output_dir "unknown_tool"
