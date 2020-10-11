import Cocoa
import AVFoundation
import CoreMediaIO

class ViewController: NSViewController {

    @IBOutlet private weak var imageView: NSImageView!

    private let fixedHeight: CGFloat = 640
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let context = CIContext()

    private var observer: NSObjectProtocol?
    private var targetRect: CGRect?

    deinit {
        stopRunning()

        if let o = observer {
            NotificationCenter.default.removeObserver(o)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // opt-in settings to find iOS physical devices
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster))
        var allow: UInt32 = 1;
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &prop, 0, nil, UInt32(MemoryLayout.size(ofValue: allow)), &allow)

        // discover target iOS device
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.externalUnknown], mediaType: nil, position: .unspecified).devices

        // configure device if found, or wait notification
        if let device = devices.filter({ $0.modelID == "iOS Device" && $0.manufacturer == "Apple Inc." }).first {
            print(device)
            self.configureDevice(device: device)
        } else {
            observer = NotificationCenter.default.addObserver(forName: .AVCaptureDeviceWasConnected, object: nil, queue: .main) { (notification) in
                print(notification)
                guard let device = notification.object as? AVCaptureDevice else { return }
                self.configureDevice(device: device)
            }
        }
    }

    private func configureDevice(device: AVCaptureDevice) {
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                if session.canAddOutput(output) {
                    output.setSampleBufferDelegate(self, queue: .main)
                    output.alwaysDiscardsLateVideoFrames = true
                    session.addOutput(output)
                }
            }
            startRunning()
        } catch {
            print(error)
        }
    }

    private func startRunning() {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    private func stopRunning() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    private func resizeIfNeeded(w: CGFloat, h: CGFloat) {
        guard targetRect == nil else { return }
        let aspect = h / fixedHeight
        let rect = CGRect(x: 0, y: 0, width: floor(w / aspect), height: fixedHeight)
        imageView.frame = rect
        targetRect = rect
    }
}

extension ViewController : AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = .portrait

        DispatchQueue.main.async(execute: {
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let w = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
            let h = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
            self.resizeIfNeeded(w: w, h: h)

            guard let targetRect = self.targetRect else { return }
            let m = CGAffineTransform(scaleX: targetRect.width / w, y: targetRect.height / h)
            let resizedImage = ciImage.transformed(by: m)
            let cgimage = self.context.createCGImage(resizedImage, from: targetRect)!
            let image = NSImage(cgImage: cgimage, size: targetRect.size)
            self.imageView.image = image
        })
    }
}
