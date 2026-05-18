# Sequence Helper Direction

OdinL should grow a useful sequence helper surface, but it should remain Odin:
simple, eager, direct, and explicit about allocation.

This is not a Clojure seq runtime. There should be no hidden lazy sequence
layer, no persistent collection abstraction, and no implicit nil-as-empty
collection behavior. Helpers should lower to readable generic Odin procedures,
ordinary indexing, ordinary slicing, ordinary loops, ordinary maps, and ordinary
dynamic arrays.

## Principles

- Preserve Odin semantics.
- Prefer eager helpers over lazy producers.
- Return slices when a helper can be a cheap view.
- Return dynamic arrays when a helper must build a new collection.
- Do not hide allocation; generated helpers that allocate should be easy to
  spot in the emitted Odin.
- Keep callbacks as plain Odin procedure values.
- Keep callback state explicit. Odin procedure literals do not capture.
- Let Odin bounds checks and type checking remain visible.
- Avoid names or behavior that imply Clojure's nullable lazy seq model.

## Current Core

These helpers are already in scope and should remain small:

```clojure
(map f xs)
(filter pred xs)
(reduce f init xs)
(take n xs)
(drop n xs)
(take-while pred xs)
(drop-while pred xs)
(find pred xs)
(some? pred xs)
(every? pred xs)
(first xs)
(second xs)
(nth xs n)
(rest xs)
```

The current implementation already supports these forms, but the ownership
model still needs tightening. In particular, `take`, `drop`, `take-while`, and
`drop-while` currently return allocated dynamic arrays, even though they can
return slice views over the original collection. The desired direction is to
change those helpers to non-owning slice views unless a future use case requires
owned variants.

Keyword callbacks are field-access shorthand in the supported higher-order
helpers:

```clojure
(map :name users)
(filter :verified users)
(->> users
     (filter :verified)
     (map :name))
```

This means "call the field accessor" for structs and struct-like values. It is
not general keyword-as-function map lookup.

## Near-Term Additions

These fit the current eager model well:

```clojure
(last xs)
(empty? xs)
(remove pred xs)
(map-indexed f xs)
(keep f xs)
(split-at n xs)
(concat xs ys)
(reverse xs)
```

Expected lowering:

- `last`, `empty?`, and simple access helpers lower to indexing, slicing, and
  `len`.
- `remove`, `map-indexed`, `keep`, `concat`, and `reverse` lower to generic
  helpers that allocate dynamic arrays.
- `split-at` should return two slices when the input is sliceable, because that
  is the direct Odin representation and does not allocate.

## Useful Additions After That

These are valuable, but each needs one deliberate design choice before
implementation:

```clojure
(partition n xs)
(partition-all n xs)
(partition-by f xs)
(zipmap keys vals)
(frequencies xs)
(group-by f xs)
(index-by f xs)
(mapcat f xs)
(sort xs)
(sort-by f xs)
(shuffle rng xs)
```

The main questions are:

- Should chunking helpers return slice views or allocated nested arrays?
- Should grouping helpers require explicit allocator arguments, use
  `context.allocator`, or follow the default dynamic-array helper convention?
- Should `sort` copy before sorting, or should there be a separate in-place
  helper?
- `shuffle` should probably require an explicit random source rather than hide
  one.

## Bounded Producers

Clojure's producer functions lean on laziness. OdinL should use explicit bounds:

```clojure
(range end)
(range start end)
(range start end step)
(repeat n x)
(repeatedly n f)
(iterate n f x)
```

These are acceptable as eager constructors because the amount of work and
allocation is visible in the call.

Avoid unbounded forms such as plain `cycle`, `repeat`, `repeatedly`, or
`iterate`. If a cyclic helper is ever added, it should be bounded:

```clojure
(cycle n xs)
```

## Transducer Path

The current eager helper shape should keep a transducer path open without
committing to it now.

Today:

```clojure
(->> users
     (filter active?)
     (map :name)
     (take 10))
```

Possible later design:

```clojure
(comp (filter active?)
      (map :name)
      (take 10))
```

That later design should still produce plain Odin code. It should not introduce
a hidden interpreter, persistent collection runtime, or lazy seq system.

## Ownership And Allocation

Sequence helpers need an explicit ownership story:

- Slice-view helpers such as `rest`, desired-view `take`/`drop` variants, and
  likely `split-at` do not own data and must not be deleted.
- Dynamic-array helpers such as `map`, `filter`, `remove`, and `reverse`
  allocate and return owned dynamic arrays.
- Until they are changed to slice views, the current `take`, `drop`,
  `take-while`, and `drop-while` implementations also return owned dynamic
  arrays.
- Examples that use allocating helpers should show `defer delete(...)` when the
  result lives beyond a trivial expression.
- Future helper docs should clearly mark whether a helper returns a view or an
  owned dynamic array.

This is a documentation and examples requirement, not just an implementation
detail. OdinL should help make Odin ownership easier to see, not easier to
forget.
