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
  | Timeout t -> Format.fprintf fmt "Timeout in %a" Timings.pp t
  | Nothing t -> Format.fprintf fmt "Nothing in %a" Timings.pp t
  | Reached t -> Format.fprintf fmt "Reached in %a" Timings.pp t
  | Other (t, code) -> Format.fprintf fmt "Other %i in %a" code Timings.pp t
  | Signaled (t, code) ->
    Format.fprintf fmt "Signaled %i in %a" code Timings.pp t
  | Stopped (t, code) -> Format.fprintf fmt "Stopped %i in %a" code Timings.pp t
