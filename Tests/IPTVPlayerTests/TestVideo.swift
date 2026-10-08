import AVFoundation
import CoreVideo
import CoreGraphics
import Foundation

/// A small H.264 file that gets brighter every second (gray = 20 + 18 * second) with a keyframe every second, so a frame tells its time.
/// The top quarter of every frame is black, so a frame that came out upside down is noticed.
/// Written with AVFoundation: no window, no external tools. Nil when this machine cannot encode.
func makeBrightnessRampVideo(seconds: Int = 12, fps: Int = 10, width: Int = 320, height: Int = 180) async -> URL? {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-ramp-\(UUID().uuidString).mp4")
    guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [AVVideoMaxKeyFrameIntervalKey: fps, AVVideoAllowFrameReorderingKey: false],
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
    ])
    writer.shouldOptimizeForNetworkUse = true   // the index first: playable from a pipe
    guard writer.canAdd(input) else { return nil }
    writer.add(input)
    guard writer.startWriting() else { return nil }
    writer.startSession(atSourceTime: .zero)
    for i in 0..<(seconds * fps) {
        var waited = 0
        while !input.isReadyForMoreMediaData && waited < 2000 { try? await Task.sleep(for: .milliseconds(5)); waited += 5 }
        guard let pool = adaptor.pixelBufferPool else { return nil }
        var pb: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb) == kCVReturnSuccess, let buf = pb else { return nil }
        CVPixelBufferLockBaseAddress(buf, [])
        let rowBytes = CVPixelBufferGetBytesPerRow(buf), base = CVPixelBufferGetBaseAddress(buf)!
        for y in 0..<height { memset(base + y * rowBytes, y < height / 4 ? 16 : Int32(20 + 18 * (i / fps)), rowBytes) }
        CVPixelBufferUnlockBaseAddress(buf, [])
        guard adaptor.append(buf, withPresentationTime: CMTime(value: Int64(i), timescale: Int32(fps))) else { return nil }
    }
    input.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else { return nil }
    return url
}

/// Average of r, g, b (0...255) of one pixel, `yFromTop` counted from the top row, read through CoreGraphics.
func gray(_ img: CGImage, x: Int, yFromTop: Int) -> Int {
    var px = [UInt8](repeating: 0, count: 4)
    let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: -x, y: -(img.height - 1 - yFromTop), width: img.width, height: img.height))
    return (Int(px[0]) + Int(px[1]) + Int(px[2])) / 3
}

func centreGray(_ img: CGImage) -> Int { gray(img, x: img.width / 2, yFromTop: img.height / 2) }
