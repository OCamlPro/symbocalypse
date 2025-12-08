  $ symbocalypse testcomp --help=plain
  NAME
         symbocalypse-testcomp - Run Test-Comp
  
  SYNOPSIS
         symbocalypse testcomp COMMAND …
  
  COMMANDS
         klee [OPTION]… [timeout]
             KLEE engine
  
         owi [OPTION]… [timeout]
             Owi engine
  
         soteria [OPTION]… [timeout]
             Soteria engine
  
         symbiotic [OPTION]… [timeout]
             Symbiotic engine
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
         --version
             Show version information.
  
  EXIT STATUS
         symbocalypse testcomp exits with:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  BUGS
         Email them to <leo@ocaml.pro>.
  
  SEE ALSO
         symbocalypse(1)
  
