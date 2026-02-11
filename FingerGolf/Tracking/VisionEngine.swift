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
}

class VisionEngine: ObservableObject {

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()
    private var smoothedLandmarks: [VNChirality: HandLandmarks] = [:]
    private let smoothingFactor: CGFloat = 0.6
    private let jumpThreshold: CGFloat = 0.15
    private let visionQueue = DispatchQueue(label: "com.fingergolf.visionQueue")

    @Published var handLandmarks: [HandLandmarks] = []
    @Published var faceRects: [CGRect] = []

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

            // Get face rectangles to filter false positives
            let detectedFaces = faceRequest.results?.map { $0.boundingBox } ?? []

            guard let observations = handRequest.results, !observations.isEmpty else {
                DispatchQueue.main.async {
                    self.handLandmarks = []
                    self.smoothedLandmarks.removeAll()
                    self.faceRects = detectedFaces
                }
                return
            }

            var currentFrameLandmarks: [HandLandmarks] = []

            for observation in observations {
                let chirality = observation.chirality

                // Require thumb and index with reasonable confidence
                guard let thumbTipPoint = try? observation.recognizedPoint(.thumbTip),
                      thumbTipPoint.confidence > 0.3,
                      let indexTipPoint = try? observation.recognizedPoint(.indexTip),
                      indexTipPoint.confidence > 0.3 else { continue }

                // Silent tracking of middle finger for stability
                let middleTipPoint = try? observation.recognizedPoint(.middleTip)
                let wristPoint = try? observation.recognizedPoint(.wrist)

                // Track additional landmarks for hand centroid
                let ringTipPoint = try? observation.recognizedPoint(.ringTip)
                let littleTipPoint = try? observation.recognizedPoint(.littleTip)

                let thumbLoc = thumbTipPoint.location
                let indexLoc = indexTipPoint.location
                let middleLoc = middleTipPoint?.confidence ?? 0 > 0.3 ? middleTipPoint?.location : nil
                let wristLoc = wristPoint?.location

                // Filter out landmarks that overlap with face bounding boxes
                if isPointInFace(thumbLoc, faceRects: detectedFaces) ||
                   isPointInFace(indexLoc, faceRects: detectedFaces) {
                    continue
                }

                // Apply smoothing
                let finalThumb: CGPoint
                let finalIndex: CGPoint

                if let previous = smoothedLandmarks[chirality] {
                    finalThumb = applySmoothing(
                        current: thumbLoc,
                        previous: previous.thumbTip ?? thumbLoc
                    )
                    finalIndex = applySmoothing(
                        current: indexLoc,
                        previous: previous.indexTip ?? indexLoc
                    )
                } else {
                    finalThumb = thumbLoc
                    finalIndex = indexLoc
                }

                // Calculate average confidence
                var totalConfidence: Float = thumbTipPoint.confidence + indexTipPoint.confidence
                var pointCount: Float = 2
                if let m = middleTipPoint, m.confidence > 0.3 {
                    totalConfidence += m.confidence
                    pointCount += 1
                }
                if let r = ringTipPoint, r.confidence > 0.3 {
                    totalConfidence += r.confidence
                    pointCount += 1
                }

                let newLandmarks = HandLandmarks(
                    chirality: chirality,
                    thumbTip: finalThumb,
                    indexTip: finalIndex,
                    middleTip: middleLoc,
                    wrist: wristLoc,
                    confidence: totalConfidence / pointCount
                )

                smoothedLandmarks[chirality] = newLandmarks
                currentFrameLandmarks.append(newLandmarks)
            }

            DispatchQueue.main.async {
                self.handLandmarks = currentFrameLandmarks
                self.faceRects = detectedFaces
            }

        } catch {
            print("VisionEngine: Failed to perform request: \(error)")
        }
    }

    // MARK: - Helpers

    private func isPointInFace(_ point: CGPoint, faceRects: [CGRect]) -> Bool {
        // Expand face rect slightly for safety margin
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
}
