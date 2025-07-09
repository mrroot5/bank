[
  version: "0.7.3",
  # Can also be set/reset with `--autocorrect`/`--no-autocorrect`.
  autocorrect: true,
  # With "--dry" no changes will be written to the files.
  # Can also be set/reset with `--dry`/`--no-dry`.
  # If dry is true then verbose is also active.
  dry: true,
  # Enables or disables color in the output.
  color: true,
  # Can also be set/reset with `--verbose`/`--no-verbose`.
  verbose: false,
  # Can be overwritten by calling `mix recode "lib/**/*.ex"`.
  inputs: ["{mix,.formatter}.exs", "{apps,config,lib,test}/**/*.{ex,exs}"],
  formatters: [Recode.CLIFormatter],
  tasks: [
    # Tasks could be added by a tuple of the tasks module name and an options
    # keyword list. A task can be deactivated by `active: false`. The execution of
    # a deactivated task can be forced by calling `mix recode --task ModuleName`.
    # Active
    {Recode.Task.AliasExpansion, []},
    {Recode.Task.AliasOrder, []},
    {Recode.Task.Dbg, []},
    {Recode.Task.FilterCount, []},
    {Recode.Task.IOInspect, []},
    {Recode.Task.PipeFunOne, []},
    {Recode.Task.SinglePipe, []},
    {Recode.Task.TestFileExt, []},
    {Recode.Task.UnnecessaryIfUnless, []},

    #
    # Disabled
    #
    # Already checked by Credo
    #
    {Recode.Task.Moduledoc, [active: false]},
    {Recode.Task.Nesting, [active: false]},
    {Recode.Task.Specs,
     [active: false, exclude: ["test/**/*.{ex,exs}", "mix.exs"], config: [only: :visible]]},
    {Recode.Task.TagFIXME, [active: false, exit_code: 2]},
    {Recode.Task.TagTODO, [active: false, exit_code: 4]},
    #
    # Others
    #
    {Recode.Task.EnforceLineLength, [active: false]},
    {Recode.Task.LocalsWithoutParens, [active: false]},
    {Recode.Task.UnusedVariable, [active: false]}
  ]
]
