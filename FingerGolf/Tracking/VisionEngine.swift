import Vision
import Combine
import UIKit

struct HandLandmarks {
    let chirality: VNChirality
    let thumbTip: CGPoint?
    let indexTip: CGPoint?
    let middleTip: CGPoint?
    let wrist: CGPoint?
    let confidence: Float
    // Full finger chains for validation (CMC/MCP → ... → TIP)
    let thumbChain: [CGPoint]
    let indexChain: [CGPoint]
}

class VisionEngine: ObservableObject {

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()
    var smoothingFactor: CGFloat = 0.6
    var jumpThreshold: CGFloat = 0.15
    private let visionQueue = DispatchQueue(label: "com.fingergolf.visionQueue")

    // Smoothed state per chirality
    private var smoothedWrist: [VNChirality: CGPoint] = [:]
    private var smoothedThumbOffset: [VNChirality: CGPoint] = [:]  // tip relative to wrist
    private var smoothedIndexOffset: [VNChirality: CGPoint] = [:]

    // Head tracking for compensation
    private var smoothedFaceCenter: CGPoint?
    private var previousFaceCenter: CGPoint?

    @Published var handLandmarks: [HandLandmarks] = []
    @Published var faceRects: [CGRect] = []
    @Published var faceCenter: CGPoint?

    // MARK: - Initialization

    init(pixelBufferPublisher: AnyPublisher<CVPixelBuffer, Never>) {
        pixelBufferPublisher
            .subscribe(on: visionQueue)
            .sink { [weak self] pixelBuffer in
                self?.processFrame(pixelBuffer)
            }
            .store(in: &cancellables)
    }

    // MARK: - Vision Processing

    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2

        let faceRequest = VNDetectFaceRectanglesRequest()

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([handRequest, faceRequest])

            // Get face rectangles
            let detectedFaces = faceRequest.results?.map { $0.boundingBox } ?? []

            // Compute face center + head delta
            let currentFaceCenter: CGPoint?
            if let faceRect = detectedFaces.first {
                currentFaceCenter = CGPoint(
                    x: faceRect.midX,
                    y: faceRect.midY
                )
            } else {
                currentFaceCenter = nil
            }

            // Head delta: how much the face moved since last frame
            let headDelta: CGPoint
            if let current = currentFaceCenter,
               let previous = previousFaceCenter {
                headDelta = CGPoint(
                    x: current.x - previous.x,
                    y: current.y - previous.y
                )
            } else {
                headDelta = .zero
            }
            previousFaceCenter = currentFaceCenter

            guard let observations = handRequest.results, !observations.isEmpty else {
                DispatchQueue.main.async {
                    self.handLandmarks = []
                    self.smoothedWrist.removeAll()
                    self.smoothedThumbOffset.removeAll()
                    self.smoothedIndexOffset.removeAll()
                    self.faceRects = detectedFaces
                    self.faceCenter = currentFaceCenter
                }
                return
            }

            var currentFrameLandmarks: [HandLandmarks] = []

            for observation in observations {
                let chirality = observation.chirality

                // --- Extract all joints ---

                // Required: thumb tip, index tip, wrist (all >0.3 confidence)
                guard let thumbTipPt = try? observation.recognizedPoint(.thumbTip),
                      thumbTipPt.confidence > 0.3,
                      let indexTipPt = try? observation.recognizedPoint(.indexTip),
                      indexTipPt.confidence > 0.3,
                      let wristPt = try? observation.recognizedPoint(.wrist),
                      wristPt.confidence > 0.3 else { continue }

                // Full thumb chain: CMC → MP → IP → TIP
                let thumbCMC = try? observation.recognizedPoint(.thumbCMC)
                let thumbMP = try? observation.recognizedPoint(.thumbMP)
                let thumbIP = try? observation.recognizedPoint(.thumbIP)

                // Full index chain: MCP → PIP → DIP → TIP
                let indexMCP = try? observation.recognizedPoint(.indexMCP)
                let indexPIP = try? observation.recognizedPoint(.indexPIP)
                let indexDIP = try? observation.recognizedPoint(.indexDIP)

                // Other tips for confidence calculation
                let middleTipPt = try? observation.recognizedPoint(.middleTip)
                let ringTipPt = try? observation.recognizedPoint(.ringTip)
                let littleTipPt = try? observation.recognizedPoint(.littleTip)

                // All MCP joints for hand centroid stability
                let middleMCP = try? observation.recognizedPoint(.middleMCP)
                let ringMCP = try? observation.recognizedPoint(.ringMCP)
                let littleMCP = try? observation.recognizedPoint(.littleMCP)

                let rawWrist = wristPt.location
                let rawThumbTip = thumbTipPt.location
                let rawIndexTip = indexTipPt.location

                // Filter out landmarks overlapping with face
                if isPointInFace(rawThumbTip, faceRects: detectedFaces) ||
                   isPointInFace(rawIndexTip, faceRects: detectedFaces) {
                    continue
                }

                // --- Head-delta compensation ---
                // Subtract head movement from raw positions to stabilize
                let compensatedWrist = CGPoint(
                    x: rawWrist.x - headDelta.x,
                    y: rawWrist.y - headDelta.y
                )
                let compensatedThumbTip = CGPoint(
                    x: rawThumbTip.x - headDelta.x,
                    y: rawThumbTip.y - headDelta.y
                )
                let compensatedIndexTip = CGPoint(
                    x: rawIndexTip.x - headDelta.x,
                    y: rawIndexTip.y - headDelta.y
                )

                // --- Compute tip-to-wrist offsets ---
                let thumbOffset = CGPoint(
                    x: compensatedThumbTip.x - compensatedWrist.x,
                    y: compensatedThumbTip.y - compensatedWrist.y
                )
                let indexOffset = CGPoint(
                    x: compensatedIndexTip.x - compensatedWrist.x,
                    y: compensatedIndexTip.y - compensatedWrist.y
                )

                // --- Finger chain validation ---
                // If DIP→TIP direction is available, validate the tip position
                let validatedThumbOffset = validateTipWithChain(
                    tipOffset: thumbOffset,
                    dipPoint: thumbIP?.confidence ?? 0 > 0.3 ? thumbIP?.location : nil,
                    wrist: compensatedWrist,
                    previousOffset: smoothedThumbOffset[chirality]
                )
                let validatedIndexOffset = validateTipWithChain(
                    tipOffset: indexOffset,
                    dipPoint: indexDIP?.confidence ?? 0 > 0.3 ? indexDIP?.location : nil,
                    wrist: compensatedWrist,
                    previousOffset: smoothedIndexOffset[chirality]
                )

                // --- Wrist-anchored smoothing ---
                let finalWrist: CGPoint
                let finalThumbOffset: CGPoint
                let finalIndexOffset: CGPoint

                if let prevWrist = smoothedWrist[chirality],
                   let prevThumbOff = smoothedThumbOffset[chirality],
                   let prevIndexOff = smoothedIndexOffset[chirality] {
                    finalWrist = applySmoothing(current: compensatedWrist, previous: prevWrist)
                    finalThumbOffset = applySmoothing(current: validatedThumbOffset, previous: prevThumbOff)
                    finalIndexOffset = applySmoothing(current: validatedIndexOffset, previous: prevIndexOff)
                } else {
                    finalWrist = compensatedWrist
                    finalThumbOffset = validatedThumbOffset
                    finalIndexOffset = validatedIndexOffset
                }

                smoothedWrist[chirality] = finalWrist
                smoothedThumbOffset[chirality] = finalThumbOffset
                smoothedIndexOffset[chirality] = finalIndexOffset

                // --- Reconstruct absolute positions ---
                let finalThumbTip = CGPoint(
                    x: finalWrist.x + finalThumbOffset.x,
                    y: finalWrist.y + finalThumbOffset.y
                )
                let finalIndexTip = CGPoint(
                    x: finalWrist.x + finalIndexOffset.x,
                    y: finalWrist.y + finalIndexOffset.y
                )

                let middleLoc = middleTipPt?.confidence ?? 0 > 0.3 ? middleTipPt?.location : nil

                // --- Build finger chains ---
                let thumbChain = buildChain([thumbCMC, thumbMP, thumbIP, thumbTipPt])
                let indexChain = buildChain([indexMCP, indexPIP, indexDIP, indexTipPt])

                // --- Calculate confidence ---
                var totalConfidence: Float = thumbTipPt.confidence + indexTipPt.confidence + wristPt.confidence
                var pointCount: Float = 3
                for pt in [middleTipPt, ringTipPt, littleTipPt, indexMCP, middleMCP, ringMCP, littleMCP] {
                    if let p = pt, p.confidence > 0.3 {
                        totalConfidence += p.confidence
                        pointCount += 1
                    }
                }

                let newLandmarks = HandLandmarks(
                    chirality: chirality,
                    thumbTip: finalThumbTip,
                    indexTip: finalIndexTip,
                    middleTip: middleLoc,
                    wrist: finalWrist,
                    confidence: totalConfidence / pointCount,
                    thumbChain: thumbChain,
                    indexChain: indexChain
                )

                currentFrameLandmarks.append(newLandmarks)
            }

            DispatchQueue.main.async {
                self.handLandmarks = currentFrameLandmarks
                self.faceRects = detectedFaces
                self.faceCenter = currentFaceCenter
            }

        } catch {
            print("VisionEngine: Failed to perform request: \(error)")
        }
    }

    // MARK: - Helpers

    private func isPointInFace(_ point: CGPoint, faceRects: [CGRect]) -> Bool {
        for rect in faceRects {
            let expanded = rect.insetBy(dx: -0.05, dy: -0.05)
            if expanded.contains(point) {
                return true
            }
        }
        return false
    }

    private func applySmoothing(current: CGPoint, previous: CGPoint) -> CGPoint {
        let dx = abs(current.x - previous.x)
        let dy = abs(current.y - previous.y)

        let effectiveFactor: CGFloat
        if dx > jumpThreshold || dy > jumpThreshold {
            effectiveFactor = 0.1 // Dampen sudden jumps
        } else {
            effectiveFactor = smoothingFactor
        }

        return CGPoint(
            x: previous.x + (current.x - previous.x) * effectiveFactor,
            y: previous.y + (current.y - previous.y) * effectiveFactor
        )
    }

    /// Validate tip offset using DIP→TIP chain direction.
    /// If the tip jumped inconsistently with the chain, dampen it.
    private func validateTipWithChain(
        tipOffset: CGPoint,
        dipPoint: CGPoint?,
        wrist: CGPoint,
        previousOffset: CGPoint?
    ) -> CGPoint {
        guard let dip = dipPoint, let prevOff = previousOffset else {
            return tipOffset
        }

        // DIP offset relative to wrist
        let dipOffset = CGPoint(x: dip.x - wrist.x, y: dip.y - wrist.y)

        // Expected tip direction: from DIP toward tip
        let chainDirX = tipOffset.x - dipOffset.x
        let chainDirY = tipOffset.y - dipOffset.y

        // Movement direction: from previous to current tip
        let moveX = tipOffset.x - prevOff.x
        let moveY = tipOffset.y - prevOff.y
        let moveMag = sqrt(moveX * moveX + moveY * moveY)

        // If the tip barely moved, no validation needed
        if moveMag < 0.005 {
            return tipOffset
        }

        // Dot product between chain direction and movement direction
        let chainMag = sqrt(chainDirX * chainDirX + chainDirY * chainDirY)
        if chainMag < 0.001 { return tipOffset }

        let dot = (chainDirX * moveX + chainDirY * moveY) / (chainMag * moveMag)

        // If movement strongly opposes chain direction, dampen it
        if dot < -0.5 {
            // Blend toward previous position (dampen the inconsistent jump)
            return CGPoint(
                x: prevOff.x + moveX * 0.2,
                y: prevOff.y + moveY * 0.2
            )
        }

        return tipOffset
    }

    /// Build a chain of points from VNRecognizedPoint optionals.
    private func buildChain(_ points: [VNRecognizedPoint?]) -> [CGPoint] {
        points.compactMap { pt in
            guard let p = pt, p.confidence > 0.3 else { return nil }
            return p.location
        }
    }
}
