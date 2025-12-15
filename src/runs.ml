type t = Run.t list

let empty = []

let add hd tl = hd :: tl

let count_all runs = List.length runs

let keep_nothing = List.filter Run.is_nothing

let count_nothing runs = List.length (keep_nothing runs)

let keep_reached = List.filter Run.is_reached

let count_reached runs = List.length (keep_reached runs)

let keep_timeout = List.filter Run.is_timeout

let count_timeout runs = List.length (keep_timeout runs)

let keep_other = List.filter Run.is_other

let count_other runs = List.length (keep_other runs)

let keep_killed = List.filter Run.is_killed

let count_killed runs = List.length (keep_killed runs)

let keep_if f runs = List.filter f runs

(* helpers *)

let sum_floats l = List.fold_left ( +. ) 0. l

let sum_int64s l = List.fold_left Int64.add 0L l

let mean_floats l = sum_floats l /. (List.length l |> float_of_int)

let mean_int64s l = Int64.div (sum_int64s l) (List.length l |> Int64.of_int)

let geometric_mean_floats l =
  match l with
  | [] -> 0.
  | l ->
    let l =
      List.filter_map
        (fun f -> if f <= 0. || Float.is_nan f then None else Some f)
        l
    in
    let log = List.map log l in
    let sum_log = sum_floats log in
    exp (sum_log /. float_of_int (List.length l))

let median_floats l =
  let n = List.length l in
  let l = List.sort Float.compare l in
  if n = 0 then 0.
  else if n mod 2 = 0 then
    let left = List.nth l (n / 2) in
    let right = List.nth l ((n / 2) + 1) in
    (left +. right) /. 2.
  else List.nth l (n / 2)

let median_int64s l =
  let n = List.length l in
  let l = List.sort Int64.compare l in
  if n = 0 then 0L
  else if n mod 2 = 0 then
    let left = List.nth l (n / 2) in
    let right = List.nth l ((n / 2) + 1) in
    Int64.div (Int64.add left right) 2L
  else List.nth l (n / 2)

let min_floats l = List.fold_left Float.min Float.max_float l

let min_int64s l = List.fold_left Int64.min Int64.max_int l

let max_floats l = List.fold_left Float.min 0. l

let max_ints64 l = List.fold_left Int64.min 0L l

(* clock *)

let sum_clock runs = List.map Run.clock runs |> sum_floats

let mean_clock runs = List.map Run.clock runs |> sum_floats

let median_clock runs = List.map Run.clock runs |> median_floats

let min_clock runs = List.map Run.clock runs |> min_floats

let max_clock runs = List.map Run.clock runs |> max_floats

(* utime *)

let sum_utime runs = List.map Run.utime runs |> sum_floats

let mean_utime runs = List.map Run.utime runs |> mean_floats

let median_utime runs = List.map Run.utime runs |> median_floats

let min_utime runs = List.map Run.utime runs |> median_floats

let max_utime runs = List.map Run.utime runs |> max_floats

(* stime *)

let sum_stime runs = List.map Run.stime runs |> sum_floats

let mean_stime runs = List.map Run.stime runs |> mean_floats

let median_stime runs = List.map Run.stime runs |> median_floats

let min_stime runs = List.map Run.stime runs |> median_floats

let max_stime runs = List.map Run.stime runs |> max_floats

(* maxrss *)

let sum_maxrss runs = List.map Run.maxrss runs |> sum_int64s

let mean_maxrss runs = List.map Run.maxrss runs |> mean_int64s

let median_maxrss runs = List.map Run.maxrss runs |> median_int64s

let min_maxrss runs = List.map Run.maxrss runs |> min_int64s

let max_maxrss runs = List.map Run.maxrss runs |> max_ints64

(* everything else! *)

let to_distribution ~max_time runs =
  List.init max_time (fun i ->
    List.fold_left
      (fun count r ->
        let clock = Run.clock r |> int_of_float in
        if clock = i then count +. 1. else count )
      0. runs )

let pp_quick_results fmt results =
  let nothing = ref 0 in
  let reached = ref 0 in
  let timeout = ref 0 in
  let killed = ref 0 in
  let other = ref 0 in
  List.iter
    (fun result ->
      match result.Run.res with
      | Nothing _ -> incr nothing
      | Reached _ -> incr reached
      | Timeout _ -> incr timeout
      | Signaled _ | Stopped _ -> incr killed
      | Other _ -> incr other )
    results;
  Fmt.pf fmt
    "Nothing: %6i    Reached: %6i    Timeout: %6i    Other: %6i    Killed: %6i"
    !nothing !reached !timeout !other !killed

let pp_table_results fmt results =
  let nothing = count_nothing results in
  let reached = count_reached results in
  let timeout = count_timeout results in
  let other = count_other results in
  let killed = count_killed results in
  let total = count_all results in
  Fmt.pf fmt
    "| Nothing | Reached | Timeout | Other | Killed | Total |@\n\
     |:-------:|:-------:|:-------:|:-----:|:------:|:-----:|@\n\
     | %6i | %6i | %6i | %6i | %6i | %6i |"
    nothing reached timeout other killed total

let pp_table_wall_clock fmt results =
  let total = sum_clock results in
  let mean = mean_clock results in
  let median = median_clock results in
  let min = min_clock results in
  let max = max_clock results in
  Fmt.pf fmt
    "| Total | Mean | Median | Min | Max |@\n\
     |:-----:|:----:|:------:|:---:|:---:|@\n\
     | %.2G | %.2G | %.2G | %.2G | %.2G |@\n"
    total mean median min max

let pp_table_user_time fmt results =
  let total = sum_utime results in
  let mean = mean_utime results in
  let median = median_utime results in
  let min = min_utime results in
  let max = max_utime results in
  Fmt.pf fmt
    "| Total | Mean | Median | Min | Max |@\n\
     |:-----:|:----:|:------:|:---:|:---:|@\n\
     | %.2G | %.2G | %.2G | %.2G | %.2G |@\n"
    total mean median min max

let pp_table_parallelism_ratio ~workers fmt results =
  let workers = float_of_int workers in
  let ratios =
    List.map
      (fun run ->
        let wall_clock_time = Run.clock run in
        let user_time = Run.utime run in
        (* TODO: make a version where we add user_time+system_time ? *)
        user_time /. wall_clock_time )
      results
  in
  let geometric_mean = geometric_mean_floats ratios in
  let geometric_mean_efficiency = geometric_mean /. workers *. 100. in
  let median = median_floats ratios in
  let median_efficiency = median /. workers *. 100. in
  let min = min_floats ratios in
  let min_efficiency = min /. workers *. 100. in
  let max = max_floats ratios in
  let max_efficiency = min /. workers *. 100. in
  Fmt.pf fmt
    "| Mean (geo) | Median | Min | Max |@\n\
     |:----:|:------:|:---:|:---:|@\n\
     | %.2G (%.2G%%) | %.2G (%.2G%%) | %.2G (%.2G%%) | %.2G (%.2G%%) |@\n"
    geometric_mean geometric_mean_efficiency median median_efficiency min
    min_efficiency max max_efficiency

let pp_table_system_time fmt results =
  let total = sum_stime results in
  let mean = mean_stime results in
  let median = median_stime results in
  let min = min_stime results in
  let max = max_stime results in
  Fmt.pf fmt
    "| Total | Mean | Median | Min | Max |@\n\
     |:-----:|:----:|:------:|:---:|:---:|@\n\
     | %.2G | %.2G | %.2G | %.2G | %.2G |@\n"
    total mean median min max

let pp_table_memory fmt results =
  let to_mb kb = Int64.div kb 1024L in
  let total = sum_maxrss results |> to_mb in
  let mean = Float.div (mean_maxrss results |> Int64.to_float) 1024. in
  let median = Float.div (median_maxrss results |> Int64.to_float) 1024. in
  let min = min_maxrss results |> to_mb in
  let max = max_maxrss results |> to_mb in
  Format.fprintf fmt
    "| Total | Mean | Median | Min | Max |@\n\
     |:-----:|:----:|:------:|:---:|:---:|@\n\
     | %Ld |  %.2G  |  %.2G  |  %Ld |  %Ld |@\n"
    total mean median min max

let map = List.map

let files = List.map (fun run -> run.Run.file)
