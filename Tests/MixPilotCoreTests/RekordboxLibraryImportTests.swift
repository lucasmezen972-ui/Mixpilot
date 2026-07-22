import Foundation
import Testing
@testable import MixPilotCore

@Suite("Rekordbox adaptive library import")
struct RekordboxLibraryImportTests {
    @Test("rekordbox-connect rows normalize database BPM and metadata")
    func rekordboxConnectRows() throws {
        let json = #"""
        {
          "dbPath": "/private/tmp/mixpilot-tests/Pioneer/rekordbox/master.db",
          "count": 1,
          "rows": [{
            "id": "rb-1",
            "title": "One More Time",
            "artist": "Daft Punk",
            "bpm": 12345,
            "length": 320,
            "key": "10B",
            "filePath": "/Music/one-more-time.mp3"
          }]
        }
        """#.data(using: .utf8)!

        let result = try RekordboxLibraryImporter().importData(json, fileExtension: "json")
        #expect(result.source == .rekordboxConnect)
        #expect(result.tracks.count == 1)
        #expect(abs(result.tracks[0].bpm - 123.45) < 0.001)
        #expect(result.tracks[0].duration == 320)
        #expect(result.tracks[0].key == "10B")
    }

    @Test("MCP snake-case schema and Spotify evidence are accepted")
    func rekordboxMCP() throws {
        let json = #"""
        {
          "rekordbox_version": "7.2.3",
          "database_path": "/tmp/master.db",
          "tracks": [{
            "id": "spotify:track:123",
            "title": "Streamed Track",
            "artist": "Artist",
            "bpm": 128,
            "length": 190,
            "play_count": 8,
            "file_path": "spotify://track/123",
            "streaming_service": "Spotify"
          }]
        }
        """#.data(using: .utf8)!

        let result = try RekordboxLibraryImporter().importData(json, fileExtension: "json")
        #expect(result.source == .rekordboxMCP)
        #expect(result.spotifyCapability == .confirmedByContent)
        #expect(result.streamingTrackCount == 1)
        #expect(result.tracks[0].playCount == 8)
    }

    @Test("OneLibrary nested reference objects are normalized")
    func oneLibrary() throws {
        let json = #"""
        {
          "deviceName": "USB DJ",
          "dbVersion": "7.4.0",
          "contents": [{
            "content_id": 42,
            "title": "Island Night",
            "artist": {"name": "Kassav"},
            "album": {"name": "Live"},
            "genre": {"name": "Zouk"},
            "key": {"name": "8A"},
            "tempo": 104.2,
            "duration_ms": 245000
          }]
        }
        """#.data(using: .utf8)!

        let result = try RekordboxLibraryImporter().importData(json, fileExtension: "json")
        #expect(result.source == .oneLibrary)
        #expect(result.spotifyCapability == .eligibleByVersion)
        #expect(result.tracks[0].artist == "Kassav")
        #expect(result.tracks[0].album == "Live")
        #expect(result.tracks[0].duration == 245)
        #expect(result.mixPilotTracks[0].profile == .zouk)
    }

    @Test("Official rekordbox XML imports collection, beat grid, cues and playlist tree")
    func officialXML() throws {
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <DJ_PLAYLISTS Version="1.0.0">
          <PRODUCT Name="rekordbox" Version="7.2.3" Company="AlphaTheta"/>
          <COLLECTION Entries="1">
            <TRACK TrackID="100" Name="XML Song" Artist="XML Artist" Genre="Afro" TotalTime="210" AverageBpm="120.5" Rating="204" Location="file://localhost/Music/song.mp3" Tonality="7A">
              <TEMPO Inizio="0.0" Bpm="120.5" Metro="4/4" Battito="1"/>
              <POSITION_MARK Name="Hot Cue A" Type="0" Start="12.5" End="0" Num="0"/>
              <POSITION_MARK Name="Loop" Type="4" Start="180" End="196" Num="-1"/>
            </TRACK>
          </COLLECTION>
          <PLAYLISTS>
            <NODE Type="0" Name="ROOT" Count="1">
              <NODE Type="1" Name="Party" KeyType="0" Entries="1">
                <TRACK Key="100"/>
              </NODE>
            </NODE>
          </PLAYLISTS>
        </DJ_PLAYLISTS>
        """#.data(using: .utf8)!

        let result = try RekordboxLibraryImporter().importData(xml, fileExtension: "xml")
        #expect(result.source == .officialXML)
        #expect(result.tracks.count == 1)
        #expect(result.tracks[0].rating == 4)
        #expect(result.tracks[0].key == "7A")
        #expect(result.tracks[0].beatGrid.count == 1)
        #expect(result.tracks[0].cues.count == 2)
        #expect(result.playlists.first?.name == "Party")
        #expect(result.playlists.first?.trackIDs == ["100"])
    }
}
