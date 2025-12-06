type t =
  | Nothing of Timings.t
  | Signaled of Timings.t * int
  | Stopped of Timings.t * int
  | Reached of Timings.t
  | Timeout of Timings.t
  | Other of Timings.t * int

val is_nothing : t -> bool

val is_killed : t -> bool

val is_reached : t -> bool

val is_timeout : t -> bool

val is_other : t -> bool

val pp : Format.formatter -> t -> unit
