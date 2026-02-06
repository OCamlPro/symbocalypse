module Unix = struct
  include Unix
  include Bos.OS.U
end

open Utils.Syntax

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

let run tool timeout max_test =
  let files = Utils.ok_or_fail (files ()) in
  Bench.run tool timeout max_test files
