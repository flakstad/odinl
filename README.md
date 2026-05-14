# odin-clj

An experiment in writing Odin with a small Clojure/Lisp-shaped syntax: Odin in
parens, not Clojure on Odin.

This is intentionally a source-to-source translator, not a new runtime or a
new semantic layer. The goal is:

- keep Odin semantics
- write paren-shaped source for editing comfort
- emit boring, readable `.odin`
- use `odin check` as the real validator

## Plan

The first milestone is a tiny translator that is pleasant enough for small
files:

- one `.oclj` file emits one `.odin` file
- forms map mechanically to Odin constructs
- generated Odin stays readable and debuggable
- Odin remains responsible for type checking, semantics, and diagnostics
- raw `(odin "...")` escape hatches are available from the start

The non-goals are just as important:

- no Clojure data model
- no persistent collections
- no seq abstraction
- no runtime library unless Odin interop absolutely needs a helper
- no semantic gap between source and generated Odin

If this grows, it should grow by covering more Odin syntax directly: structs,
enums, unions, pointers, slices, arrays, `defer`, `using`, `when`, `or_return`,
allocators, attributes, procedures, packages, and imports. It should not grow
by inventing a new language on top of Odin.

## Example

```clojure
(package main)

(import "core:fmt")

(proc main [] void
  (fmt.println "hello from odin-clj")
  (let x int 41)
  (fmt.println (+ x 1)))
```

emits:

```odin
package main

import "core:fmt"

main :: proc() {
    fmt.println("hello from odin-clj")
    x: int = 41
    fmt.println(x + 1)
}
```

## Usage

```sh
python3 -m src.odin_clj examples/hello.oclj -o /tmp/hello.odin
odin check /tmp/hello.odin -file
```

If `-o` is omitted, generated Odin is written to stdout.

## Current Forms

- `(package name)`
- `(import "core:fmt")`
- `(proc name [(arg type) ...] return-type body...)`
- `(let name type expr)` -> `name: type = expr`
- `(let name expr)` -> `name := expr`
- `(const name type expr)` -> `name: type : expr`
- `(const name expr)` -> `name :: expr`
- `(set! place expr)` -> `place = expr`
- `(return expr)`
- `(if test then else)`
- `(when test body...)`
- `(for [init test post] body...)`
- `(for-in name collection body...)`
- `(block body...)`
- `(odin "...")` raw Odin escape hatch
- calls: `(foo a b)` -> `foo(a, b)`
- operators: `(+ a b)`, `(<= i 10)`, `(and a b)`, etc. emit infix

This is deliberately incomplete. Add only forms that map cleanly to Odin.

## Design Rules

- Prefer transparent lowering over clever abstraction.
- Keep generated Odin idiomatic enough to read and edit.
- Use Odin syntax and names for types.
- Add forms only when their Odin output is obvious.
- Prefer an explicit raw Odin escape hatch over guessing.
- Treat `odin check` as the source of truth.
