// Upstream SFCGAL v2.2.0 parity cases intentionally not ported yet.
//
// The UpstreamParity*.swift files are additive tests beside the existing
// SwiftSFCGAL suite. They adapt upstream v2.2.0 cases only where the current
// public Swift API can express the same behavior.
//
// Skipped for missing wrappers:
// - dimension, coordinateDimension, numGeometries on non-collections
// - isEmpty, isMeasured, isSimple
// - equality / almost-equality operators
// - boundary, envelope, centroid
// - dropZ, dropM, forceZ, forceM, swapXY
// - forceRHR, forceLHR
// - setter/replacement mutators such as setPatchN, setExteriorRing, setGeometryN
// - M / ZM coordinate accessors and coordinate type inspection
// - direct WKT char-array length API
// - direct expected native-endian WKB fixture comparison against upstream data files
// - empty-geometry WKB round-trips until the Swift wrapper defines supported
//   payload behavior for empty geometries
// - WKB round-trips for SFCGAL-specific TIN/Solid families until the wrapper
//   exposes supported payload behavior for those geometry types
// - direct PostGIS EWKB writer/reader coverage beyond current EWKT/WKB round-trips
// - OBJ/STL/VTK export
// - lineSubstring, buffer3D, minkowskiSum, offsetPolygon, visibility
// - algorithm option variants such as volume(..., NoValidityCheck); this keeps
//   VolumeTest.cpp / cubeWithHoleVolume out of scope until the Swift API can
//   express the same interior-shell validity behavior as upstream.
//
// Skipped or reduced for stability:
// - Upstream file-driven predicate and boolean tests are represented with stable
//   inline WKT cases instead of copying upstream data files.
// - Very large known-crash regression fixtures are not copied into the Swift
//   suite; they should become focused regression tests when wrapper behavior
//   and timeout expectations are formalized.
// - Invalid typed-collection insertions such as adding a LineString to a
//   MultiPoint are skipped until Swift has a type-safe or exception-safe API
//   for those negative paths.
// - Alpha-shape parity is compiled only outside Windows because SFCGAL excludes
//   the alpha-shapes C API from MSVC builds.
