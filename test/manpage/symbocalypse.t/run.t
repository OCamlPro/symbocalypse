  $ symbocalypse --help=plain
  NAME
         symbocalypse - Symbocalypse benchmarking tool
  
  SYNOPSIS
         symbocalypse [COMMAND] …
  
  COMMANDS
         diff [OPTION]… FILE1 FILE2
             Compare two benchmarks results
  
         report [OPTION]… FILE
             Generate a report from existing benchmarks results
  
         testcomp COMMAND …
             Run Test-Comp
  
         version [OPTION]…
             Print some version informations
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
         --version
             Show version information.
  
  EXIT STATUS
         symbocalypse exits with:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  BUGS
         Email them to <leo@ocaml.pro>.
  
