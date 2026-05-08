# Benchmarks

This folder contains reproducible benchmarks for APIs whose value depends on
reducing Swift/C boundary overhead.

## Batch Operations

Run the benchmark in release mode.

macOS/Linux:

```bash
swift run -c release BatchOperationsBenchmark
```

Windows with SFCGAL installed to `C:\sfcgal`:

```powershell
swift run -c release -Xcc -IC:/sfcgal/include -Xlinker /LIBPATH:C:\sfcgal\lib BatchOperationsBenchmark
```

The benchmark generates 120 CityGML-like building surfaces and compares:

- Swift loop: `geometries.map { try $0.tesselate() }`
- C batch: `batchTesselate(geometries)`
- Swift pipeline: WKT parse -> tesselate -> vertex extraction in Swift
- C pipeline: `batchWKTToVertices(_:vertexCapacity:)`

Issue 8.1 uses a 5% threshold: if plain batch tesselation is under that
threshold, the API should be reconsidered. The WKT-to-vertices pipeline is
tracked separately because it removes more intermediate Swift object traffic.

## Latest Local Result

Recorded on Windows, Swift 6.1 release build, SFCGAL installed at `C:\sfcgal`,
using the generated 120-surface CityGML-like benchmark workload:

```text
Batch Operations Benchmark
Surfaces: 120
Iterations: 10 measured, 3 warmup

Swift loop tesselate: 43.379 ms median
C batch tesselate: 44.564 ms median
Swift WKT -> vertices pipeline: 39.400 ms median
C WKT -> vertices pipeline: 38.638 ms median

Batch tesselate speedup: -2.73%
WKT-to-vertices speedup: 1.93%
Batch tesselate is below the 5% public API threshold on this run.
WKT-to-vertices is below the 5% threshold on this run.
```

This result does not satisfy the Issue 8.1 threshold for keeping a public batch
tesselation API. Before closing the issue, rerun this benchmark against a real
CityGML sample with at least 100 building surfaces and document that result in
the GitHub issue.
