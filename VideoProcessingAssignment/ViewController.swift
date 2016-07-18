//
//  ViewController.swift
//  VideoProcessingAssignment
//
//  Created by NexGear on 17/07/16.
//  Copyright © 2016 NexGear. All rights reserved.
//

import UIKit
import DKImagePickerController
import AVFoundation
import MediaPlayer

class ViewController: UIViewController {
    
    @IBOutlet var informationLabel : UILabel!
    var filePath: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        informationLabel.text = "No Videos Picked Yet"
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func onClickOfPickVideosButton(sender:AnyObject){
        informationLabel.text = "Picking Videos from Photo Gallery"
        let videoFilePaths = NSMutableArray()
        var importedFilesCounter = 0
        let pickerController = DKImagePickerController()
        pickerController.allowMultipleTypes=false
        pickerController.singleSelect=false
        pickerController.maxSelectableCount = 2
        pickerController.assetType=DKImagePickerControllerAssetType.AllVideos
        pickerController.didSelectAssets = { [unowned self] (assets: [DKAsset]) in
            for asset in assets{
                let filePath = self.getNewFilePathToSaveVideo()
                videoFilePaths.addObject(filePath)
                dispatch_async(dispatch_get_main_queue(), {
                    self.informationLabel.text = "Now importing videos into application"
                })
                asset.writeAVToFile(filePath, presetName: AVAssetExportPreset1280x720, completeBlock: { (success) in
                    if success{
                        print("video imported to \(filePath)")
                        importedFilesCounter += 1
                        if importedFilesCounter == videoFilePaths.count{
                            self.checkVideosAndMerge(videoFilePaths)
                        }
                    }else{
                        dispatch_async(dispatch_get_main_queue(), {
                            self.informationLabel.text = "Importing of video operation failed"
                        })
                    }
                })
            }
        }
        self.presentViewController(pickerController, animated: true) {}
    }
    
    @IBAction func onClickOfPickLastVideoButton(sender:AnyObject){
        if filePath != nil {
            dispatch_async(dispatch_get_main_queue(), {
                let moviePlayerViewController = MPMoviePlayerViewController(contentURL: NSURL(fileURLWithPath: self.filePath))
                self.presentViewController(moviePlayerViewController, animated: true) {}
                moviePlayerViewController.moviePlayer.play()
            })
        }
    }
    
    func checkVideosAndMerge(videoFilePaths:NSMutableArray) {
        self.informationLabel.text = "Video imported ! merging them now"
        AksVideoProcessingHelper.sharedInstance.mergeVideos(videoFilePaths, completion: { (returnedData) in
            dispatch_async(dispatch_get_main_queue(), {
                let moviePlayerViewController = MPMoviePlayerViewController(contentURL: NSURL(fileURLWithPath: (returnedData! as! String)))
                self.presentViewController(moviePlayerViewController, animated: true) {}
                moviePlayerViewController.moviePlayer.play()
                self.informationLabel.text = "Merging completed and New video has been saved in Photos Library"
                self.filePath = returnedData as! String
            })
        })
    }
    
    var counter = 0
    func getNewFilePathToSaveVideo() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        let directoryPath = paths[0]
        while true {
            counter += 1
            if NSFileManager.defaultManager().fileExistsAtPath("\(directoryPath)/Video\(counter).mp4") == false{
                return "\(directoryPath)/Video\(counter).mp4"
            }
        }
    }
}

