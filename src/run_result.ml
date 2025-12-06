type t =
  | Nothing of Timings.t
  | Signaled of Timings.t * int
  | Stopped of Timings.t * int
  | Reached of Timings.t
  | Timeout of Timings.t
  | Other of Timings.t * int

let is_nothing = function Nothing _ -> true | _ -> false

let is_killed = function Signaled _ | Stopped _ -> true | _ -> false

let is_reached = function Reached _ -> true | _ -> false

let is_timeout = function Timeout _ -> true | _ -> false

let is_other = function Other _ -> true | _ -> false

let pp fmt = function
  | Timeout t ->
    Format.fprintf fmt "Timeout in %.2G %.2G %.2G" t.clock t.utime t.stime
  | Nothing t ->
    Format.fprintf fmt "Nothing in %.2G %.2G %.2G" t.clock t.utime t.stime
  | Reached t ->
    Format.fprintf fmt "Reached in %.2G %.2G %.2G" t.clock t.utime t.stime
  | Other (t, code) ->
    Format.fprintf fmt "Other %i in %.2G %.2G %.2G" code t.clock t.utime t.stime
  | Signaled (t, code) ->
    Format.fprintf fmt "Signaled %i in %.2G %.2G %.2G" code t.clock t.utime
      t.stime
  | Stopped (t, code) ->
    Format.fprintf fmt "Stopped %i in %.2G %.2G %.2G" code t.clock t.utime
      t.stime
