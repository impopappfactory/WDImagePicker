//
//  WDImagePicker.swift
//  WDImagePicker
//
//  Created by Wu Di on 27/8/15.
//  Copyright (c) 2015 Wu Di. All rights reserved.
//

import UIKit

@objc public protocol WDImagePickerDelegate {
    optional func imagePicker(imagePicker: WDImagePicker, pickedImage: UIImage)
    optional func imagePickerDidCancel(imagePicker: WDImagePicker)
}

@objc public class WDImagePicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, WDImageCropControllerDelegate {
    public var delegate: WDImagePickerDelegate?
    public var cropSize: CGSize!
    public var resizableCropArea = false

    private var _imagePickerController: UIImagePickerController!

    public var imagePickerController: UIImagePickerController {
        return _imagePickerController
    }

    override public init() {
        super.init()

        self.cropSize = CGSize(width: 320, height: 320)
        _imagePickerController = UIImagePickerController()
        _imagePickerController.delegate = self
        _imagePickerController.sourceType = .PhotoLibrary

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(cameraChanged), name: "AVCaptureDeviceDidStartRunningNotification", object: nil)
    }

    @objc func cameraChanged(notification: NSNotification) {
        guard _imagePickerController.sourceType == .Camera else { return }
        if(_imagePickerController.cameraDevice == .Front) {
            self.imagePickerController.cameraViewTransform = CGAffineTransformIdentity
            self.imagePickerController.cameraViewTransform = CGAffineTransformScale(self.imagePickerController.cameraViewTransform, -1, 1)
        } else {
            self.imagePickerController.cameraViewTransform = CGAffineTransformIdentity
        }
    }

    private func hideController() {
        self._imagePickerController.dismissViewControllerAnimated(true, completion: nil)
    }

    public func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        if self.delegate?.imagePickerDidCancel != nil {
            self.delegate?.imagePickerDidCancel!(self)
        } else {
            self.hideController()
        }
    }

    public func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let cropController = WDImageCropViewController()
        cropController.sourceImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        cropController.resizableCropArea = self.resizableCropArea
        cropController.cropSize = self.cropSize
        cropController.delegate = self
        picker.pushViewController(cropController, animated: true)
    }

    func imageCropController(imageCropController: WDImageCropViewController, didFinishWithCroppedImage croppedImage: UIImage) {
        self.delegate?.imagePicker?(self, pickedImage: croppedImage)
    }


    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

}
