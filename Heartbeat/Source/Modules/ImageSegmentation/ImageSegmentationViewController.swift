//
//  ImageSegmentationViewController
//  Heartbeat
//
//  Created by Chris Kelly on 9/12/2018.
//  Copyright © 2018 Fritz Labs, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import AlamofireImage
import Vision
import Fritz
import VideoToolbox



class ImageSegmentationViewController: UIViewController {

    @IBOutlet weak var cameraView: UIView!

    var cameraImageView: UIImageView!

    var imageView: UIImageView!

    var maskView: UIImageView!

    private lazy var cameraSession = AVCaptureSession()

    private let visionModel = FritzVisionPeopleSegmentationModel()

    private let sessionQueue = DispatchQueue(label: "com.fritz.heartbeat.mobilenet.session")

    private let captureQueue = DispatchQueue(label: "com.fritz.heartbeat.mobilenet.capture", qos: DispatchQoS.userInitiated)

    override func viewDidLoad() {
        super.viewDidLoad()

        let bounds = cameraView.layer.bounds

        cameraImageView = UIImageView(frame: bounds)
        maskView = UIImageView(frame: bounds)
        imageView = UIImageView(frame: bounds)
        // Adding mask view

        imageView.contentMode = .scaleAspectFill
        cameraImageView.contentMode = .scaleAspectFill
        maskView.contentMode = .scaleAspectFill

        // add blurview
        let blurView = CustomBlurView(withRadius: 6.0)
        blurView.frame = self.cameraView.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        cameraImageView.addSubview(blurView)

        imageView.mask = maskView

        cameraView.addSubview(cameraImageView)
        cameraView.addSubview(imageView)

        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else { return }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA as UInt32]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: captureQueue)

        sessionQueue.async {
            self.cameraSession.beginConfiguration()
            // self.cameraSession.sessionPreset = AVCaptureSession.Preset.vga640x480
            self.cameraSession.addInput(input)
            self.cameraSession.addOutput(output)
            self.cameraSession.commitConfiguration()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        sessionQueue.async {
            self.cameraSession.startRunning()
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        cameraImageView.frame = cameraView.bounds
        imageView.frame = cameraView.bounds
        maskView.frame = cameraView.bounds
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
    }
}


extension ImageSegmentationViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        let image = FritzVisionImage(buffer: sampleBuffer)
        image.metadata = FritzVisionImageMetadata()
        let options = FritzVisionSegmentationModelOptions()
        options.imageCropAndScaleOption = .scaleFit

        visionModel.predict(image, options: options) { [weak self] (mask, error) in
            guard let mask = mask else { return }
            let maskImage = mask.toImageMask(of: FritzVisionPeopleClass.person, threshold: 0.70, minThresholdAccepted: 0.25)
            let backgroundVideo = UIImage(pixelBuffer: image.rotate()!)
            DispatchQueue.main.async {
                self?.imageView.image = backgroundVideo
                self?.maskView.image = maskImage
                self?.cameraImageView.image = backgroundVideo
            }
        }
    }
}

