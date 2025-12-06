(* TODO: put the tool in the output in order to be able to reprint it, instead of using "unknown_tool" *)
let run result_file =
  let runs = Parse.from_file result_file in
  let output_dir = Fpath.v "./" in
  Gen.full_report runs output_dir "unknown_tool"
