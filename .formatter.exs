# Used by "mix format"
locals_without_parens = [
  field: 2,
  field: 3,
  field: 4,
  resolve_list: 1,
  resolve_aggregate: 1
]

[
  inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
