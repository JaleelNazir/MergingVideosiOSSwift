//
//  AksVideoProcessingHelper.swift
//  VideoProcessingAssignment
//
//  Created by NexGear on 17/07/16.
//  Copyright © 2016 NexGear. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import AssetsLibrary

typealias AKSVideoProcessingHelperCompletionBlock = (returnedData :AnyObject?) ->()

let fixedVideoSize = CGSizeMake(1280,720)

class AksVideoProcessingHelper: NSObject{
    var completionBlock: AKSVideoProcessingHelperCompletionBlock?
    var assetsArray = NSMutableArray()
    class var sharedInstance: AksVideoProcessingHelper {
        struct Static {
            static var onceToken: dispatch_once_t = 0
            static var instance: AksVideoProcessingHelper? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = AksVideoProcessingHelper()
        }
        return Static.instance!
    }
    
    private override init() {
        
    }
    
    func mergeVideos(videos:NSArray,completion:AKSVideoProcessingHelperCompletionBlock) {
        assetsArray.removeAllObjects()
        completionBlock = completion
        for filePath in videos {
            let asset = AVAsset(URL: NSURL(fileURLWithPath:filePath as! String))
            assetsArray.addObject(asset)
        }
        mergeVideos()
    }
    
    private func addAssets(information:NSDictionary) {
        let asset = AVAsset(URL: NSURL(fileURLWithPath:information.objectForKey("filePath") as! String))
        assetsArray.addObject(asset)
    }
    
    private func mergeVideos(){
        if assetsArray.count > 0{
            let mixComposition = AVMutableComposition()
            let layerInstructionsArray = NSMutableArray()
            var time = kCMTimeZero
            for object in assetsArray {
                if let asset = object as? AVAsset{
                    let track = mixComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
                    do {
                        try track.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), ofTrack: asset.tracksWithMediaType(AVMediaTypeVideo)[0], atTime: time)
                    }catch{}
                    let layerInstructions = prepareVideoCompositionInstruction(track, asset: asset)
                    time = CMTimeAdd(time, asset.duration)
                    if assetsArray.lastObject?.isEqual(asset) == false {
                        layerInstructions.setOpacity(0.0, atTime: time)
                    }
                    layerInstructionsArray.addObject(layerInstructions)
                }
            }
            let mainInstruction = AVMutableVideoCompositionInstruction()
            mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, time)
            mainInstruction.layerInstructions = NSArray(array: layerInstructionsArray) as! [AVVideoCompositionLayerInstruction]
            
            let mainCompositionInstruction = AVMutableVideoComposition()
            mainCompositionInstruction.instructions = NSArray(object: mainInstruction) as! [AVVideoCompositionInstructionProtocol]
            mainCompositionInstruction.frameDuration = CMTimeMake(1, 30)
            mainCompositionInstruction.renderSize = fixedVideoSize
            
            let filePath = getNewFilePathToSaveVideo()
            let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
            exporter?.outputURL = NSURL(fileURLWithPath: filePath)
            exporter?.outputFileType = AVFileTypeQuickTimeMovie
            exporter?.videoComposition = mainCompositionInstruction
            exporter?.exportAsynchronouslyWithCompletionHandler({
                self.completionBlock!(returnedData: filePath)
                if exporter?.status == AVAssetExportSessionStatus.Completed{
                    let saveToPhotos = true
                    if saveToPhotos {
                        let library = ALAssetsLibrary()
                        if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(exporter?.outputURL){
                            library.writeVideoAtPathToSavedPhotosAlbum(exporter?.outputURL, completionBlock: { (url, error) in
                                if error != nil{
                                    print(error)
                                }
                            })
                        }
                    }
                }
            })
        }
    }
    
    private func getVideoOrientationFromTransform(transform: CGAffineTransform) -> (orientation: UIImageOrientation, isPortrait: Bool) {
        var assetOrientation = UIImageOrientation.Up
        var isPortrait = false
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .Right
            isPortrait = true
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .Left
            isPortrait = true
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .Up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .Down
        }
        return (assetOrientation, isPortrait)
    }
    
    private func prepareVideoCompositionInstruction(track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let assetTrack = asset.tracksWithMediaType(AVMediaTypeVideo)[0]
        let transform = assetTrack.preferredTransform
        let assetInfo = getVideoOrientationFromTransform(transform)
        
        var scaleToFitRatio = 0.0 as CGFloat
        if assetInfo.isPortrait {
            scaleToFitRatio = fixedVideoSize.height / assetTrack.naturalSize.width
            let scaleFactor = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio)
            let xFix = CGFloat(((assetTrack.naturalSize.width - fixedVideoSize.height*scaleToFitRatio)/2))
            let transform1 = CGAffineTransformConcat(assetTrack.preferredTransform, scaleFactor)
            let transform2 = CGAffineTransformConcat(transform1,CGAffineTransformMakeTranslation(xFix,0))
            instruction.setTransform(transform2,atTime: kCMTimeZero)
        } else {
            scaleToFitRatio = fixedVideoSize.width / assetTrack.naturalSize.width
            let scaleFactor = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio)
            let yFix = CGFloat((fixedVideoSize.height - (assetTrack.naturalSize.height/scaleToFitRatio))/2)
            var concat = CGAffineTransformConcat(CGAffineTransformConcat(assetTrack.preferredTransform, scaleFactor), CGAffineTransformMakeTranslation(0, yFix))
            if assetInfo.orientation == .Down {
                let fixUpsideDown = CGAffineTransformMakeRotation(CGFloat(M_PI))
                let windowBounds = UIScreen.mainScreen().bounds
                let yFix = assetTrack.naturalSize.height + windowBounds.height
                let centerFix = CGAffineTransformMakeTranslation(assetTrack.naturalSize.width, yFix)
                concat = CGAffineTransformConcat(CGAffineTransformConcat(fixUpsideDown, centerFix), scaleFactor)
            }
            instruction.setTransform(concat, atTime: kCMTimeZero)
        }
        return instruction
    }
    
    private func getNewFilePathToSaveVideo() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        let directoryPath = paths[0]
        var counter = 0
        while true {
            counter += 1
            if NSFileManager.defaultManager().fileExistsAtPath("\(directoryPath)/Video\(counter).mp4") == false{
                return "\(directoryPath)/Video\(counter).mp4"
            }
        }
    }
}