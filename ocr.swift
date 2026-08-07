import Vision
import AppKit

// Usage: swift ocr.swift <image-path>
// Prints all recognized text to stdout, one line per text line.

guard CommandLine.arguments.count > 1 else {
    fputs("usage: swift ocr.swift <image-path>\n", stderr)
    exit(1)
}

let path = CommandLine.arguments[1]
guard let img = NSImage(contentsOfFile: path),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Could not load image: \(path)\n", stderr)
    exit(1)
}

let request = VNRecognizeTextRequest { req, _ in
    guard let obs = req.results as? [VNRecognizedTextObservation] else { return }
    let lines = obs.compactMap { $0.topCandidates(1).first?.string }
    print(lines.joined(separator: "\n"))
}
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true

let handler = VNImageRequestHandler(cgImage: cg, options: [:])
try handler.perform([request])
