import AVFoundation
import Combine
import UIKit

@MainActor
class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Properties

    nonisolated(unsafe) private let captureSession = AVCaptureSession()
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private var isConfigured = false
    private let sessionQueue = DispatchQueue(label: "com.fingergolf.sessionQueue")

    nonisolated let pixelBufferPublisher = PassthroughSubject<CVPixelBuffer, Never>()

    @Published var isSessionRunning = false
    @Published var permissionGranted = false

    // MARK: - Initialization

    override init() {
        super.init()
        // Don't configure session here — defer until startSession() is called
        // after camera permission is granted. This avoids blocking the main thread
        // and avoids AVFoundation work before permissions are ready.
    }

    // MARK: - Permission

    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.permissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.permissionGranted = granted
                }
            }
        case .denied, .restricted:
            self.permissionGranted = false
        @unknown default:
            self.permissionGranted = false
        }
    }

    // MARK: - Session Setup (runs on sessionQueue, off main thread)

    nonisolated private func configureSession() {
        guard !isConfigured else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        // Front camera - prefer ultra-wide for larger FOV
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )

        guard let videoDevice = discovery.devices.first,
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoDeviceInput) else {
            print("CameraManager: Could not create video device input.")
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(videoDeviceInput)

        // Configure video output
        if captureSession.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            captureSession.addOutput(videoOutput)

            // Set rotation for portrait
            if let connection = videoOutput.connection(with: .video) {
                let coordinator = AVCaptureDevice.RotationCoordinator(
                    device: videoDevice, previewLayer: nil
                )
                if connection.isVideoRotationAngleSupported(coordinator.videoRotationAngleForHorizonLevelCapture) {
                    connection.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelCapture
                }
            }
        }

        captureSession.commitConfiguration()
        isConfigured = true
    }

    // MARK: - Session Control (runs on sessionQueue, off main thread)

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            // Configure on first start (always on sessionQueue, never main thread)
            self.configureSession()
            guard !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            Task { @MainActor in
                self.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                Task { @MainActor in
                    self.isSessionRunning = false
                }
            }
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        pixelBufferPublisher.send(pixelBuffer)
    }
}
