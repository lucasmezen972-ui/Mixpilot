#if os(macOS)
/// Canonical product name for the importer that converts visible Accessibility
/// rows into MixPilot tracks. The implementation remains shared while legacy
/// source files migrate away from their historical Serato-specific name.
public typealias VisiblePlaylistImporter = SeratoPlaylistImporter
#endif
