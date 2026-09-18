import SwiftUI
import AVFoundation

public struct CameraPreviewView: UIViewRepresentable {
    public class VideoPreviewUIView: UIView {
        public override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        public var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
            if let conn = previewLayer.connection {
                if #available(iOS 17.0, *), conn.isVideoRotationAngleSupported(90) {
                    conn.videoRotationAngle = 90
                } else if conn.isVideoOrientationSupported {
                    conn.videoOrientation = .portrait
                }
            }
        }
    }

    public let session: AVCaptureSession
    public let onLayerAvailable: (AVCaptureVideoPreviewLayer) -> Void

    public init(session: AVCaptureSession, onLayerAvailable: @escaping (AVCaptureVideoPreviewLayer) -> Void) {
        self.session = session
        self.onLayerAvailable = onLayerAvailable
    }

    public func makeUIView(context: Context) -> VideoPreviewUIView {
        let view = VideoPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let conn = view.previewLayer.connection {
            if #available(iOS 17.0, *), conn.isVideoRotationAngleSupported(90) {
                conn.videoRotationAngle = 90
            } else if conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
        }

        DispatchQueue.main.async {
            onLayerAvailable(view.previewLayer)
        }
        return view
    }

    public func updateUIView(_ uiView: VideoPreviewUIView, context: Context) {
        uiView.previewLayer.frame = uiView.bounds
        DispatchQueue.main.async {
            onLayerAvailable(uiView.previewLayer)
        }
    }
}
