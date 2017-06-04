//
//  WDImageCropView.swift
//  WDImagePicker
//
//  Created by Wu Di on 27/8/15.
//  Copyright (c) 2015 Wu Di. All rights reserved.
//

import UIKit
import QuartzCore

private class ScrollView: UIScrollView {
    private override func layoutSubviews() {
        super.layoutSubviews()

        if let zoomView = self.delegate?.viewForZoomingInScrollView?(self) {
            let boundsSize = self.bounds.size
            var frameToCenter = zoomView.frame

            // center horizontally
            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }

            // center vertically
            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }

            zoomView.frame = frameToCenter
        }
    }
}

internal class WDImageCropView: UIView, UIScrollViewDelegate {
    var resizableCropArea = false

    private var scrollView: UIScrollView!
    private var imageView: UIImageView!
    private var cropOverlayView: WDImageCropOverlayView!
    private var xOffset: CGFloat!
    private var yOffset: CGFloat!

    private static func scaleRect(rect: CGRect, scale: CGFloat) -> CGRect {
        return CGRectMake(
            rect.origin.x * scale,
            rect.origin.y * scale,
            rect.size.width * scale,
            rect.size.height * scale)
    }

    var imageToCrop: UIImage? {
        get {
            return self.imageView.image
        }
        set {
            self.imageView.image = newValue
        }
    }

    var cropSize: CGSize {
        get {
            return self.cropOverlayView.cropSize
        }
        set {
            if let view = self.cropOverlayView {
                view.cropSize = newValue
            } else {
                if self.resizableCropArea {
                    self.cropOverlayView = WDResizableCropOverlayView(frame: self.bounds,
                        initialContentSize: CGSizeMake(newValue.width, newValue.height))
                } else {
                    self.cropOverlayView = WDImageCropOverlayView(frame: self.bounds)
                }
                self.cropOverlayView.cropSize = newValue

                self.addSubview(self.cropOverlayView)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.userInteractionEnabled = true
        self.backgroundColor = UIColor.clearColor()
        self.scrollView = ScrollView(frame: frame)
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.delegate = self
        self.scrollView.clipsToBounds = false
        self.scrollView.decelerationRate = 0
        self.scrollView.backgroundColor = UIColor.clearColor()
        self.addSubview(self.scrollView)

        self.imageView = UIImageView(frame: self.scrollView.frame)
        self.imageView.contentMode = .ScaleAspectFill
        self.imageView.backgroundColor = UIColor.clearColor()
        self.scrollView.addSubview(self.imageView)

        self.scrollView.minimumZoomScale = 1
//            CGRectGetWidth(self.scrollView.frame) / CGRectGetHeight(self.scrollView.frame)
        self.scrollView.maximumZoomScale = 1
        self.scrollView.setZoomScale(1.0, animated: false)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        if !resizableCropArea {
            return self.scrollView
        }

        let resizableCropView = cropOverlayView as! WDResizableCropOverlayView
        let outerFrame = CGRectInset(resizableCropView.cropBorderView.frame, -10, -10)

        if outerFrame.contains(point) {
            if resizableCropView.cropBorderView.frame.size.width < 60 ||
                resizableCropView.cropBorderView.frame.size.height < 60 {
                    return super.hitTest(point, withEvent: event)
            }

            let innerTouchFrame = CGRectInset(resizableCropView.cropBorderView.frame, 30, 30)
            if innerTouchFrame.contains(point) {
                return self.scrollView
            }

            let outBorderTouchFrame = CGRectInset(resizableCropView.cropBorderView.frame, -10, -10)
            if outBorderTouchFrame.contains(point) {
                return super.hitTest(point, withEvent: event)
            }

            return super.hitTest(point, withEvent: event)
        }

        return self.scrollView
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cropSize = self.cropSize
        let toolbarSize = CGFloat(UIDevice.currentDevice().userInterfaceIdiom == .Pad ? 0 : 54)
        self.xOffset = floor((CGRectGetWidth(self.bounds) - cropSize.width) * 0.5)
        self.yOffset = floor((CGRectGetHeight(self.bounds) - toolbarSize - cropSize.height) * 0.5)

        let height = self.imageToCrop!.size.height
        let width = self.imageToCrop!.size.width

        var factor: CGFloat = 0
        var factoredHeight: CGFloat = 0
        var factoredWidth: CGFloat = 0

        let maximumImageHeight: CGFloat = 1000
        let maximumImageWidth: CGFloat = 781.25
        let maximumZoom: CGFloat

        if width > height {
            factor = height / cropSize.height
            factoredWidth = width / factor
            factoredHeight = cropSize.height
            maximumZoom = self.imageToCrop!.size.height / maximumImageHeight
        } else {
            factor = width / cropSize.width
            factoredWidth = cropSize.width
            factoredHeight =  height / factor
            maximumZoom = self.imageToCrop!.size.width / maximumImageWidth
        }

        self.cropOverlayView.frame = self.bounds
        self.scrollView.frame = CGRectMake(xOffset, yOffset, cropSize.width, cropSize.height)
        self.scrollView.contentSize = CGSize(width: factoredWidth, height: factoredHeight)
        if let _ = self.imageToCrop {
            self.scrollView.maximumZoomScale = maximumZoom
        }

        self.imageView.frame = CGRectMake(floor((cropSize.width - factoredWidth) * 0.5), floor((cropSize.height - factoredHeight) * 0.5),
            factoredWidth, factoredHeight)
    }

    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }

    func scrollViewDidEndZooming(scrollView: UIScrollView, withView view: UIView?, atScale scale: CGFloat) {
        var visibleRect = resizableCropArea ?
            calcVisibleRectForResizeableCropArea() : calcVisibleRectForCropArea()

        // transform visible rect to image orientation
        let rectTransform = orientationTransformedRectOfImage(imageToCrop!)
        visibleRect = CGRectApplyAffineTransform(visibleRect, rectTransform)
    }

    func croppedImage() -> UIImage {
        // Calculate rect that needs to be cropped
        var visibleRect = resizableCropArea ?
            calcVisibleRectForResizeableCropArea() : calcVisibleRectForCropArea()

        // transform visible rect to image orientation
        let rectTransform = orientationTransformedRectOfImage(imageToCrop!)
        visibleRect = CGRectApplyAffineTransform(visibleRect, rectTransform)

        // finally crop image
        let imageRef = CGImageCreateWithImageInRect(imageToCrop!.CGImage, visibleRect)
        let result = UIImage(CGImage: imageRef!, scale: imageToCrop!.scale,
            orientation: imageToCrop!.imageOrientation)

        return result
    }

    private func calcVisibleRectForResizeableCropArea() -> CGRect {
        let resizableView = cropOverlayView as! WDResizableCropOverlayView

        // first of all, get the size scale by taking a look at the real image dimensions. Here it
        // doesn't matter if you take the width or the hight of the image, because it will always
        // be scaled in the exact same proportion of the real image
        var sizeScale = self.imageView.image!.size.width / self.imageView.frame.size.width
        sizeScale *= self.scrollView.zoomScale

        // then get the postion of the cropping rect inside the image
        var visibleRect = resizableView.contentView.convertRect(resizableView.contentView.bounds,
            toView: imageView)
        visibleRect = WDImageCropView.scaleRect(visibleRect, scale: sizeScale)

        return visibleRect
    }

    private func calcVisibleRectForCropArea() -> CGRect {
        // scaled width/height in regards of real width to crop width
        let scaleWidth = imageToCrop!.size.width / cropSize.width
        let scaleHeight = imageToCrop!.size.height / cropSize.height
        var scale: CGFloat = 0

        if cropSize.width == cropSize.height {
            scale = max(scaleWidth, scaleHeight)
        } else if cropSize.width > cropSize.height {
            scale = imageToCrop!.size.width < imageToCrop!.size.height ?
                max(scaleWidth, scaleHeight) :
                min(scaleWidth, scaleHeight)
        } else {
            scale = imageToCrop!.size.width < imageToCrop!.size.height ?
                min(scaleWidth, scaleHeight) :
                max(scaleWidth, scaleHeight)
        }
        var visibleRect = CGRect.zero
        visibleRect.origin = scrollView.contentOffset
        visibleRect.size = scrollView.bounds.size

        let relativeX = visibleRect.origin.x / self.imageView.frame.size.width
        let relativeY = visibleRect.origin.y / self.imageView.frame.size.height
        let relativeWidth = visibleRect.width / self.imageView.frame.size.width
        let relativeHeight = visibleRect.height / self.imageView.frame.size.height

        let visibleWidth = self.imageToCrop!.size.width * relativeWidth
        let visibleHeight = self.imageToCrop!.size.height * relativeHeight
        visibleRect = CGRectMake(
            self.imageToCrop!.size.width * relativeX,
            self.imageToCrop!.size.height * relativeY,
            visibleWidth,
            visibleHeight
        )
        return visibleRect
    }

    private func orientationTransformedRectOfImage(image: UIImage) -> CGAffineTransform {
        var rectTransform: CGAffineTransform!

        switch image.imageOrientation {
        case .Left:
            rectTransform = CGAffineTransformTranslate(
                CGAffineTransformMakeRotation(CGFloat(M_PI_2)), 0, -image.size.height)
        case .Right:
            rectTransform = CGAffineTransformTranslate(
                CGAffineTransformMakeRotation(CGFloat(-M_PI_2)), -image.size.width, 0)
        case .Down:
            rectTransform = CGAffineTransformTranslate(
                CGAffineTransformMakeRotation(CGFloat(-M_PI)),
                -image.size.width, -image.size.height)
        default:
            rectTransform = CGAffineTransformIdentity
        }

        return CGAffineTransformScale(rectTransform, image.scale, image.scale)
    }
}
