# odin-clj

An experiment in writing Odin with a small Clojure/Lisp-shaped syntax.

This is intentionally a source-to-source translator, not a new runtime or a
new semantic layer. The goal is:

- keep Odin semantics
- write paren-shaped source for editing comfort
- emit boring, readable `.odin`
- use `odin check` as the real validator

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
