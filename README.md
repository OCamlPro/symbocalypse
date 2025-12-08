# Symbocalypse -- Symbolic Execution Benchmarks

## Building

You first need to install the required dependencies, either through `opam` or `nix`.

```shell-session
$ dune build @install --profile release -p symbocalypse
$ dune exec -- symbocalypse --help
```

## Fetching the benchmarks and the tools

This may take a while and use a lot of disk space.

```shell-session
$ git submodule update --init --depth 1
```

## Running Test-Comp

If you intend to run `owi` or `soteria`, you should make sure they are built with symbocalypse:

```shell-session
$ dune build @install --profile release -p symbocalypse,owi # for Owi
$ dune build @install --profile release -p symbocalypse,owi # for Soteria
```

Then, you can run Test-Comp with the tool of your choice. You could for instance run with a five seconds timeout:

```shell-session
$ symbocalypse testcomp owi 5
```

A folder `testcomp-results-XYZ/results` has been created with a lot of output. It contains `results-report/index.html` which is the recommended way to visualize the results.

You can replace `owi` by another tool, but also use special options for each tool. To get the list of available tools you can do:

```shell-session
$ symbocalypse testcomp --help
```

To get the available options for a tool you can do:

```shell-session
$ symbocalypse testcomp owi --help
```

### Zulip notification:

You can set up the script to notify you or a stream on Zulip using the Zulip Slack incoming webhook integration.
For information on creating webhooks, see [this](https://zulip.com/integrations/doc/slack_incoming#zulip-slack-incoming-webhook-integration).
Next, just set the `ZULIP_WEBHOOK` environment variable with the generated webhook and launch the script:

```shell-session
$ export ZULIP_WEBHOOK="https://saussice.zulipchat.com/api/v1/external/slack_incoming?api_key=...&stream=germany&topic=bratwurst"
$ symbocalypse testcomp 5
```

## Generate the report by hand

```shell-session
$ symbocalypse report testcomp-results-XYZ/results
```

A folder `results-report` should be available in the working directory with the `index.html` file that contains the results.

## Comparing two runs

```shell-session
$ symbocalypse diff testcomp-results-XYZ/results testcomp-results-ABC/results
```

## Hacking

If you want to run the tests, you should do:

```shell-session
$ dune runtest test/
```
