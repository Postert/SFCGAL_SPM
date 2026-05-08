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

When `Benchmarks/data/LoD3-HH_HafenCity_CityGML.gml` is present, the benchmark extracts
real Hamburg CityGML building surfaces from that file. If no CityGML file is
available, it falls back to generated CityGML-like surfaces.

You can choose a CityGML file explicitly:

```bash
swift run -c release BatchOperationsBenchmark -- --input Benchmarks/data/LoD3-HH_HafenCity_CityGML.gml
```

You can cap the number of extracted source surfaces for faster local runs:

```bash
swift run -c release BatchOperationsBenchmark -- --max-surfaces 200
```

The benchmark compares:

- Swift loop: `geometries.map { try $0.tesselate() }`
- C batch: `batchTesselate(geometries)`
- Swift pipeline: WKT parse -> tesselate -> vertex extraction in Swift
- C pipeline: `batchWKTToVertices(_:vertexCapacity:)`

Issue 8.1 uses a 5% threshold: if plain batch tesselation is under that
threshold, the API should be reconsidered. The WKT-to-vertices pipeline is
tracked separately because it removes more intermediate Swift object traffic.

## Latest Local Result

Recorded on Windows, Swift 6.1 release build, SFCGAL installed at `C:\sfcgal`,
using real Hamburg CityGML data from
`Benchmarks/data/LoD3-HH_HafenCity_CityGML.gml` with `--max-surfaces 200`:

```text
Batch Operations Benchmark
Dataset: LoD3-HH_HafenCity_CityGML.gml
Source: C:/Users/mafia/Desktop/HCU/Work/Swift_Apps/SFCGAL_SPM/Benchmarks/data/LoD3-HH_HafenCity_CityGML.gml
Extracted surfaces: 200
Usable surfaces: 151
Rejected surfaces: 49
Iterations: 10 measured, 3 warmup

Swift loop tesselate: 343.753 ms median
C batch tesselate: 348.997 ms median
Swift WKT -> vertices pipeline: 341.309 ms median
C WKT -> vertices pipeline: 316.176 ms median

Batch tesselate speedup: -1.53%
WKT-to-vertices speedup: 7.36%
Batch tesselate is below the 5% public API threshold on this run.
```

This 200-surface result satisfies the Issue 8.1 threshold for the full
WKT-to-vertices pipeline, but does not justify keeping plain `batchTesselate(_:)`
as a public API.

Larger real-data runs did not reproduce the pipeline speedup:

```text
Dataset: LoD3-HH_HafenCity_CityGML.gml
Extracted surfaces: 500
Usable surfaces: 419
Rejected surfaces: 81

Swift loop tesselate: 859.688 ms median
C batch tesselate: 864.058 ms median
Swift WKT -> vertices pipeline: 950.060 ms median
C WKT -> vertices pipeline: 941.238 ms median

Batch tesselate speedup: -0.51%
WKT-to-vertices speedup: 0.93%
```

```text
Dataset: LoD2_567_5931_1_HH.xml
Extracted surfaces: 500
Usable surfaces: 498
Rejected surfaces: 2

Swift loop tesselate: 849.748 ms median
C batch tesselate: 860.197 ms median
Swift WKT -> vertices pipeline: 1006.908 ms median
C WKT -> vertices pipeline: 1025.714 ms median

Batch tesselate speedup: -1.23%
WKT-to-vertices speedup: -1.87%
```

Current conclusion: the existing Hamburg datasets support much larger
benchmarks, but the speedup is not stable. Plain batch tessellation should not
be public. The WKT-to-vertices pipeline is useful as a low-level experiment, but
needs a stronger benchmark result before it should be positioned as a guaranteed
performance win.
