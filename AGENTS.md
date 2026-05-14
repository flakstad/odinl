# odin-clj Agent Notes

This repo is an experiment in writing Odin with a Lisp/Clojure-shaped surface.
The project goal is **Odin in parens**, not Clojure semantics on Odin.

## Direction

- Preserve Odin semantics.
- Emit readable, boring `.odin`.
- Keep the translator small and source-to-source.
- Let `odin check` validate the generated code.
- Prefer mechanical syntax lowering over abstraction.
- Treat REPL-like tooling as temp Odin generation plus `odin run`, not as an
  interpreter.
- Treat `[]` and `{}` as Odin literal sugar, not as Clojure collections.

## Non-Goals

- Do not add a runtime unless a tiny helper is unavoidable.
- Do not introduce persistent collections, seqs, dynamic vars, namespaces, or
  other Clojure semantics.
- Do not hide Odin concepts behind new abstractions.
- Do not make generated Odin hard to inspect.
- Do not build a fake stateful REPL or hidden dynamic environment.

## Implementation

- Main translator: `src/odin_clj.py`.
- Tests: `tests/test_odin_clj.py`.
- Examples: `examples/*.oclj`.
- Run tests with `python3 -m unittest discover -s tests`.
- Check generated Odin with `odin check <file>.odin -file`.
- Future eval-selection support should generate a scratch Odin entry point and
  run/check that with Odin itself.

## Style

- Add forms only when the Odin output is obvious.
- Keep raw escape hatch support via `(odin "...")`.
- Favor simple, explicit syntax over clever inference.
- Keep examples small and executable.
- Prefer explicit type-directed literal forms such as `(slice int [...])`,
  `(map string int {...})`, and `(Person {...})`.
