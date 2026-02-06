val runs : Tool.t -> float -> Fpath.t -> int -> Fpath.t list -> Runs.t

val notify_finished : Runs.t -> float -> string -> Fpath.t -> int -> unit

val run :
  Tool.t -> float -> int -> Fpath.t list -> (unit, [ `Msg of string ]) result
