type t

val to_short_name : t -> string

val to_reference_name : t -> string

val tool_path_env_var_name : string

val mk_owi :
     bench:bool
  -> exploration_strategy:string
  -> optimisation_level:int
  -> solver:Smtml.Solver_type.t
  -> workers:int
  -> t

val mk_klee : unit -> t

val mk_soteria : unit -> t

val mk_symbiotic : unit -> t

val check_if_available : t -> (unit, [ `Msg of string ]) Result.t

val fork_and_run_on_file :
     i:int
  -> fmt:Format.formatter
  -> output_dir:Fpath.t
  -> file:Fpath.t
  -> tool:t
  -> timeout:float
  -> (Run_result.t, [ `Msg of string ]) Result.t
