#!/usr/bin/env python3
"""Reproduce the public synthetic GPX with the app's unchanged serializer (macOS).

Fixture types supply values only. This does not exercise GPS, SwiftData, export
filtering, purchase gates, file sharing, or the full ExportService.render pipeline.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SAMPLE = ROOT / "marketing/public/samples/synthetic-app-export.gpx"
NS = {"g": "http://www.topografix.com/GPX/1/1"}
FIXTURES = r'''
import Foundation
struct Visit {
    let latitude: Double; let longitude: Double; let arrivedAt: Date
    let departedAt: Date?; let exportLocationName: String?; let address: String?
    let notes: String?; let durationMinutes: Double?
}
struct LocationPoint {
    let latitude: Double; let longitude: Double; let timestamp: Date
    let altitude: Double?; let speed: Double?; let horizontalAccuracy: Double
    let isOutlier: Bool
}
struct ExportOptions {
    var includeVisitCoordinates = true; var includeVisitLocationName = true
    var includeVisitAddress = true; var includeVisitNotes = true
    var includeVisitDuration = true; var includePointAltitude = true
    var includePointSpeed = true; var includePointAccuracy = true
    var includePointOutlierFlag = true
}
struct ExportService {
    static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
'''
MAIN = r'''
import Foundation
let base = Date(timeIntervalSince1970: 946728000)
let offsets: [TimeInterval] = [0, 60, 120, 780, 840]
let points = offsets.enumerated().map { index, offset in
    LocationPoint(latitude: Double(index) * 0.0001,
                  longitude: Double(index) * 0.0001,
                  timestamp: base.addingTimeInterval(offset),
                  altitude: Double(index), speed: 1,
                  horizontalAccuracy: 5, isOutlier: false)
}
// Reverse input to verify that the serializer sorts by timestamp.
let data = ExportService.exportLocationPointsToGPX(points: points.reversed())
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
'''


def normalized(data):
    root = ET.fromstring(data)
    root.find("g:metadata/g:time", NS).text = "EXPORT-TIME"
    return ET.tostring(root)


def check(write=False):
    source = (ROOT / "IsoMe/Utilities/ExportService.swift").read_text()
    serializer = source[source.index("// MARK: - GPX Export"):
                        source.index("// MARK: - KML Export")]
    with tempfile.TemporaryDirectory(prefix="isome-gpx-sample-") as directory:
        folder = Path(directory)
        (folder / "Serializer.swift").write_text(FIXTURES + serializer)
        (folder / "main.swift").write_text(MAIN)
        subprocess.run(["swiftc", "-module-cache-path", str(folder / "cache"),
                        str(folder / "Serializer.swift"), str(folder / "main.swift"),
                        "-o", str(folder / "render")], check=True)
        output = folder / "export.gpx"
        subprocess.run([str(folder / "render"), str(output)], check=True)
        data = output.read_bytes()
    root = ET.fromstring(data)
    assert root.attrib == {"version": "1.1", "creator": "iso.me"}
    segments = root.findall("g:trk/g:trkseg", NS)
    assert [len(segment) for segment in segments] == [3, 2]
    points = root.findall("g:trk/g:trkseg/g:trkpt", NS)
    assert [p.find("g:time", NS).text for p in points] == [
        "2000-01-01T12:00:00.000Z", "2000-01-01T12:01:00.000Z",
        "2000-01-01T12:02:00.000Z", "2000-01-01T12:13:00.000Z",
        "2000-01-01T12:14:00.000Z"]
    assert [(p.attrib["lat"], p.attrib["lon"]) for p in points] == [
        (f"{i * 0.0001:.7f}", f"{i * 0.0001:.7f}") for i in range(5)]
    assert len(root.findall("g:wpt", NS)) == 0
    if write:
        SAMPLE.write_bytes(data)
        print(f"Wrote {SAMPLE.relative_to(ROOT)}")
    assert normalized(SAMPLE.read_bytes()) == normalized(data), "Public GPX differs from app serializer"
    print("Passed actual GPX serializer: 5 synthetic points, sorted timestamps, 2 segments (11-minute gap); public sample matches except export time.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Replace the public synthetic sample with fresh serializer bytes")
    check(parser.parse_args().write)
