//
//  GIFMaker.swift
//  VideoToGIF
//
//  Created by lujianqiao on 2019/3/26.
//  Copyright © 2019 NGY. All rights reserved.
//
import UIKit
import Foundation
import MobileCoreServices

import ImageIO
import AVFoundation
import PKHUD

public typealias TimePoint = CMTime

/// Errors thrown by Regift
public enum GIFMakerError: String, Error {
    case DestinationNotFound = "The temp file destination could not be created or found"
    case SourceFormatInvalid = "The source file does not appear to be a valid format"
    case AddFrameToDestination = "An error occurred when adding a frame to the destination"
    case DestinationFinalize = "An error occurred when finalizing the destination"
}
// Convenience struct for managing dispatch groups.
private struct Group {
    let group = DispatchGroup()
    func enter() { group.enter() }
    func leave() { group.leave() }
    func wait() { let _ = group.wait(timeout: DispatchTime.distantFuture) }
}

public struct  GIFMaker{
    
    fileprivate struct Constants {
        static let FileName = "regift.gif"
        static let TimeInterval: Int32 = 600
        static let Tolerance = 0.01
    }
    
    /// The url for the source file.
    fileprivate let sourceFileURL: URL
    
    /// A reference to the asset we are converting.
    fileprivate var asset: AVAsset
    
    /// The total length of the movie, in seconds.
    fileprivate var movieLength: Float
    
    /// The desired duration of the gif.
    fileprivate var duration: Float
    
    /// The amount of time each frame will remain on screen in the gif.
    fileprivate let delayTime: Float
    
    /// The number of times the gif will loop (0 is infinite).
    fileprivate let loopCount: Int

    
    /// The number of frames we are going to use to create the gif.
    fileprivate let frameCount: Int
    
    /// The point in time in the source which we will start from.
    fileprivate var startTime: Float = 0
    
    public init(sourceFileURL: URL, frameCount: Int, delayTime: Float, loopCount: Int = 0) {
        self.sourceFileURL = sourceFileURL
        self.asset = AVURLAsset(url: sourceFileURL, options: nil)
        self.movieLength = Float(asset.duration.value) / Float(asset.duration.timescale)
        self.duration = movieLength
        self.delayTime = delayTime
        self.loopCount = loopCount
        self.frameCount = Int(movieLength * Float(frameCount))
    }
    
    
    public static func creatGIFFormSource(fileURL: URL, frameCount: Int, delatTime: Float, loopCount: Int = 0, completion: (_ result: URL?) -> Void){
        let gif = GIFMaker(sourceFileURL: fileURL, frameCount: frameCount, delayTime: delatTime, loopCount: loopCount)
    
        completion(gif.makerGIF())
    
    }
    
    public static func creatGIFFormImages(images: [UIImage], completion: (_ result: URL?) -> Void) {

        
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let gifPath = docs[0] as String + "/refresh.gif"
        
        let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, gifPath as CFString, .cfurlposixPathStyle, false)
        let destion = CGImageDestinationCreateWithURL(url!, kUTTypeGIF, images.count, nil)
        
        // 设置gif图片属性
        // 设置每帧之间播放的时间0.1
        let delayTime = [kCGImagePropertyGIFDelayTime as String:0.1]
        let destDic   = [kCGImagePropertyGIFDictionary as String:delayTime]
        // 依次为gif图像对象添加每一帧属性
        for image in images {
            CGImageDestinationAddImage(destion!, image.cgImage!, destDic as CFDictionary?)
        }
        
        let propertiesDic: NSMutableDictionary = NSMutableDictionary()
        propertiesDic.setValue(kCGImagePropertyColorModelRGB, forKey: kCGImagePropertyColorModel as String)
        propertiesDic.setValue(16, forKey: kCGImagePropertyDepth as String)         // 设置图片的颜色深度
        propertiesDic.setValue(1, forKey: kCGImagePropertyGIFLoopCount as String)   // 设置Gif执行次数
        
        let gitDestDic = [kCGImagePropertyGIFDictionary as String:propertiesDic]    // 为gif图像设置属性
        CGImageDestinationSetProperties(destion!, gitDestDic as CFDictionary?)
        CGImageDestinationFinalize(destion!)
        
        completion(URL(fileURLWithPath: gifPath))
        
    }
    
    
    
    public func makerGIF() -> URL? {
        let fileProperties = [kCGImagePropertyGIFDictionary as String:[
            kCGImagePropertyGIFLoopCount as String: NSNumber(value: Int32(loopCount) as Int32)],
                              kCGImagePropertyGIFHasGlobalColorMap as String: NSValue(nonretainedObject: true)
            ] as [String : Any]
        
        let frameProperties = [
            kCGImagePropertyGIFDictionary as String:[
                kCGImagePropertyGIFDelayTime as String:delayTime
            ]
        ]
        
        // How far along the video track we want to move, in seconds.
        let increment = Float(duration) / Float(frameCount)
        
        // Add each of the frames to the buffer
        var timePoints: [TimePoint] = []
        for frameNumber in 0 ..< frameCount {
            let seconds: Float64 = Float64(startTime) + (Float64(increment) * Float64(frameNumber))
            let time = CMTimeMakeWithSeconds(seconds, preferredTimescale: Constants.TimeInterval)
            
            timePoints.append(time)
        }
        
        do {
            return try createGIFForTimePoints(timePoints, fileProperties: fileProperties as [String : AnyObject], frameProperties: frameProperties as [String : AnyObject], frameCount: frameCount)
        } catch {
            return nil
        }
    }
    
    public func createGIFForTimePoints(_ timePoints: [TimePoint], fileProperties: [String: AnyObject], frameProperties: [String: AnyObject], frameCount: Int) throws -> URL {
        
        // Ensure the source media is a valid file.
        guard asset.tracks(withMediaCharacteristic: AVMediaCharacteristic.visual).count > 0 else {
            throw GIFMakerError.SourceFormatInvalid
        }
        
        var fileURL : URL?
        let temporaryFile = (NSTemporaryDirectory() as NSString).appendingPathComponent(Constants.FileName)
        fileURL = URL(fileURLWithPath: temporaryFile)
        
        guard let destination = CGImageDestinationCreateWithURL(fileURL! as CFURL, kUTTypeGIF, frameCount, nil) else {
            throw GIFMakerError.DestinationNotFound
        }
        
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        
        let generator = AVAssetImageGenerator(asset: asset)
        
        generator.appliesPreferredTrackTransform = true
        
        let tolerance = CMTimeMakeWithSeconds(Constants.Tolerance, preferredTimescale: Constants.TimeInterval)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        
        // Transform timePoints to times for the async asset generator method.
        var times = [NSValue]()
        for time in timePoints {
            times.append(NSValue(time: time))
        }
        
        // Create a dispatch group to force synchronous behavior on an asynchronous method.
        let gifGroup = Group()
        var dispatchError: Bool = false
        gifGroup.enter()
        
        generator.generateCGImagesAsynchronously(forTimes: times, completionHandler: { (requestedTime, image, actualTime, result, error) in
            guard let imageRef = image , error == nil else {
                print("An error occurred: \(String(describing: error)), image is \(String(describing: image))")
                dispatchError = true
                gifGroup.leave()
                return
            }
            
            CGImageDestinationAddImage(destination, imageRef, frameProperties as CFDictionary)
            
            if requestedTime == times.last?.timeValue {
                gifGroup.leave()
            }
        })
        
        // Wait for the asynchronous generator to finish.
        gifGroup.wait()
        
        // If there was an error in the generator, throw the error.
        if dispatchError {
            throw GIFMakerError.AddFrameToDestination
        }
        
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        
        // Finalize the gif
        if !CGImageDestinationFinalize(destination) {
            throw GIFMakerError.DestinationFinalize
        }
        
        return fileURL!
    }
}
