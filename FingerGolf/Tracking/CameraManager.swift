import AVFoundation
import Combine
import UIKit

@MainActor
class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Properties

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.fingergolf.sessionQueue")

    nonisolated let pixelBufferPublisher = PassthroughSubject<CVPixelBuffer, Never>()

    @Published var isSessionRunning = false
    @Published var permissionGranted = false

    // MARK: - Initialization

    override init() {
        super.init()
        setupSession()
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
                    if granted {
                        self.startSession()
                    }
                }
            }
        case .denied, .restricted:
            self.permissionGranted = false
        @unknown default:
            self.permissionGranted = false
        }
    }

    // MARK: - Session Setup

    private func setupSession() {
        Task { @MainActor in
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
                await withCheckedContinuation { continuation in
                    sessionQueue.async {
                        self.videoOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
                        continuation.resume()
                    }
                }
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
        }
    }

    // MARK: - Session Control

    func startSession() {
        guard !captureSession.isRunning else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.captureSession.startRunning()
                self.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
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
