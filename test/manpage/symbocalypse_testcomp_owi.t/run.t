  $ symbocalypse testcomp owi --help=plain
  NAME
         symbocalypse-testcomp-owi - Owi engine
  
  SYNOPSIS
         symbocalypse testcomp owi [OPTION]… [timeout]
  
  OPTIONS
         --exploration=VAL (absent=rarity-depth-loop-aging-random)
             exploration strategy to use ("fifo", "lifo" or "random")
  
         --max-tests=VAL (absent=100000)
             maximum number of tests to run
  
         -O VAL (absent=1)
             specify which optimization level to use
  
         -s VALUE, --solver=VALUE (absent=Z3)
             SMT solver to use. VALUE must be one of the 5 available solvers:
             Z3, Bitwuzla, Colibri2, cvc5, Alt-Ergo
  
         -w VAL, --workers=VAL (absent=n)
             number of workers for symbolic execution. Defaults to the number
             of physical cores.
  
  COMMON OPTIONS
         --bench
             enable benchmarks
  
         --color=WHEN (absent=auto)
             Colorize the output. WHEN must be one of auto, always or never.
  
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
         -q, --quiet
             Be quiet. Takes over -v and --verbosity.
  
         -v, --verbose
             Increase verbosity. Repeatable, but more than twice does not bring
             more.
  
         --verbosity=LEVEL (absent=warning or SYMBOCALYPSE_VERBOSITY env)
             Be more or less verbose. LEVEL must be one of quiet, error,
             warning, info or debug. Takes over -v.
  
         --version
             Show version information.
  
  EXIT STATUS
         symbocalypse testcomp owi exits with:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  ENVIRONMENT
         These environment variables affect the execution of symbocalypse
         testcomp owi:
  
         SYMBOCALYPSE_VERBOSITY
             See option --verbosity.
  
  BUGS
         Email them to <leo@ocaml.pro>.
  
  SEE ALSO
         symbocalypse(1)
  
