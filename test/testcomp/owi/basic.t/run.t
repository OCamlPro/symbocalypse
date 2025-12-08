Testing it fails to find the correct path:
  $ symbocalypse testcomp owi
  symbocalypse: [ERROR] Could not find the expected file at `_build/install/default/bin/owi`.
  symbocalypse: [ERROR] Make sure you cloned the submodule with: git submodule update --init --depth 1 tools/owi
  symbocalypse: [ERROR] Then run: dune build @install -p symbocalypse,owi --profile release
  symbocalypse: [ERROR] :-(
  [121]
Providing the correct path:
  $ S_TOOL_PATH=owi symbocalypse testcomp owi 1 --max-test 3
  ERROR: directory contents benchs/sv-benchmarks/c/: No such file or directory
  [1]
