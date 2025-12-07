type t =
  { clock : float
  ; utime : float
  ; stime : float
  ; maxrss : int64
  }

let pp fmt { clock; utime; stime; maxrss } =
  Fmt.pf fmt "%.2G %.2G %.2G %LdMB" clock utime stime (Int64.div maxrss 1024L)
