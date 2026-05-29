# Benchmark Notes

Current benchmark harness:

- `./scripts/bench_sequence_helpers.sh`
- `./scripts/bench_aggregate_helpers.sh`

These compare generated Kvist output against hand-written Odin for the same
workloads.

## What The Current Numbers Say

There are two distinct cases.

### 1. Near-parity lowering

When Kvist source already looks close to Odin control flow and mutation, the
generated code is very close to the direct Odin version.

Examples from the current runs:

- aggregate report benchmark:
  - `report-group`: Kvist `45.881 ms`, direct Odin `46.303 ms`
  - `report-aggregate`: Kvist `42.632 ms`, direct Odin `42.864 ms`
  - `report-loop`: Kvist `17.950 ms`, direct Odin `18.232 ms`

- sequence/helper benchmark examples:
  - `sort`: Kvist `2.774 ms`, direct Odin `2.735 ms`
  - `sort-by`: Kvist `3.517 ms`, direct Odin `3.502 ms`
  - `orders-ptr-loop`: Kvist `3.158 ms`, direct Odin `3.069 ms`
  - `orders-map!`: Kvist `4.729 ms`, direct Odin `4.681 ms`

This is the encouraging case. It means the source-to-source lowering itself is
not introducing meaningful overhead when the source model already matches the
host model.

### 2. High-level helper pipelines versus fused loops

Some of the largest gaps are not "bad codegen" so much as "different
semantics":

- `pipe-map-filter`: Kvist `26.532 ms`, direct Odin `0.797 ms`
- `pipe-filter-map`: Kvist `10.806 ms`, direct Odin `0.013 ms`
- `orders-revenue`: Kvist `14.348 ms`, direct Odin `1.361 ms`
- `orders-threaded`: Kvist `14.039 ms`, direct Odin `1.319 ms`

In these cases the Kvist version is using eager helper pipelines that allocate
intermediate results, while the Odin version is a hand-fused loop with no
intermediate collections.

That is an important distinction:

- the generated Odin is still honest
- but the source abstraction carries real runtime cost

So these numbers are useful pressure, not a compiler bug by themselves.

## Current Conclusion

The compiler is already doing a good job of mechanical lowering.

The main performance question is now:

- where should Kvist expose high-level eager helpers with explicit cost?
- where should we encourage in-place or loop-oriented forms?
- where do we want future optimization/fusion passes, if any?

## Good Next Benchmarks

The next benchmark additions should target language features we recently added,
not only older sequence helpers.

Recommended next cases:

1. `update!` on structs, arrays, and maps
2. `update` on structs versus hand-written copy-update Odin
3. pointer mutation versus by-value struct update
4. `for`/`each` loops over arrays, maps, and sets

These would tell us whether the newer language surface is still lowering as
cleanly as the older helper benchmarks.
