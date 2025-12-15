val notify_finished : Runs.t -> float -> string -> Fpath.t -> int -> unit

val run: Tool.t -> float -> int -> (unit, [`Msg of string]) Result.t
