//
//  VideoEditor.swift
//  ExportVideo
//
//  Created by Ayushi on 09/06/21.
//

import UIKit
import AVFoundation

final class VideoEditor {
    func export(fromVideoAt videoURL: URL, onComplete: @escaping (URL?) -> Void) {
        export(fromVideo: videoURL, to: .MP4, completionHandler: onComplete)
//        changeBitrate(url: videoURL, completion: onComplete)
    }
    
    func export(fromVideo videoURL: URL, to type: MediaType, completionHandler: @escaping (URL?) -> Void) {
        guard videoURL.pathExtension != type.fileExtension() else {
            print("Same file format")
            completionHandler(nil)
            return
        }

        let asset = AVAsset(url: videoURL)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        let preset = AVAssetExportPresetHighestQuality
        let outFileType = AVFileType.mp4
        let outputUrl = URL(fileURLWithPath: NSTemporaryDirectory())
          .appendingPathComponent(formatter.string(from: Date()))
            .appendingPathExtension(type.fileExtension())
        
        AVAssetExportSession.determineCompatibility(ofExportPreset: preset,
                                                    with: asset,
                                                    outputFileType: outFileType) { isCompatible in
            guard isCompatible else { return }
            // Compatibility check succeeded, continue with export.
            guard let exportSession = AVAssetExportSession(asset: asset,
                                                           presetName: preset) else { return }
            exportSession.outputFileType = outFileType
            exportSession.outputURL = outputUrl
            exportSession.exportAsynchronously {
                // Handle export results.
                switch exportSession.status {
                case .failed:
                    print(exportSession.error ?? "NO ERROR")
                    completionHandler(nil)
                case .cancelled:
                    print("Export canceled")
                    completionHandler(nil)
                case .completed:
                    //Video conversion finished
                    print("Successful!")
                    print(exportSession.outputURL ?? "NO OUTPUT URL")
                    completionHandler(exportSession.outputURL)
                case .unknown:
                    print("Export Unknown Error")
                default: break
                }
            }
        }
    }
    
    private func changeBitrate(url: URL, completion:@escaping (URL?) -> Void) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
          .appendingPathComponent(formatter.string(from: Date()))
            .appendingPathExtension("mov")
        var audioFinished = false
        var videoFinished = false
        let asset = AVAsset(url: url)
        
        var assetReader: AVAssetReader?
        var assetWriter: AVAssetWriter?
        
        //create asset reader
        do{
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            assetReader = nil
        }
        
        guard let reader = assetReader else {
            print("Could not initalize asset reader probably failed its try catch")
            completion(nil)
            return
        }
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let audioTrack = asset.tracks(withMediaType: .audio).first else {
            completion(nil)
            return
        }
        
        let videoReaderSettings: [String:Any] =  [String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32ARGB ]
        
        // Adjust bitrate of video here
        let videoSettings: [String:Any] = [
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey:  NSNumber(integerLiteral: Constants.videoBitrate)],
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoHeightKey: videoTrack.naturalSize.height,
            AVVideoWidthKey: videoTrack.naturalSize.width
        ]
        
        let assetReaderVideoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)
        let assetReaderAudioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
        
        
        if reader.canAdd(assetReaderVideoOutput) {
            reader.add(assetReaderVideoOutput)
        } else {
            fatalError("Couldn't add video output reader")
        }
        
        if reader.canAdd(assetReaderAudioOutput){
            reader.add(assetReaderAudioOutput)
        } else {
            fatalError("Couldn't add audio output reader")
        }
        
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.transform = videoTrack.preferredTransform
        //we need to add samples to the video input
        
        let videoInputQueue = DispatchQueue(label: "videoQueue")
        let audioInputQueue = DispatchQueue(label: "audioQueue")
        
        do{
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mov)
        } catch {
            assetWriter = nil
        }
        guard let writer = assetWriter else {
            fatalError("assetWriter was nil")
        }
        
        writer.shouldOptimizeForNetworkUse = true
        writer.add(videoInput)
        writer.add(audioInput)
        
        
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: .zero)
        
        
        let closeWriter:()-> Void = {
            if (audioFinished && videoFinished){
                self.assetWriter?.finishWriting(completionHandler: {
                    completion(self.assetWriter?.outputURL)
                })
                self.assetReader?.cancelReading()
            }
        }
        
        
        audioInput.requestMediaDataWhenReady(on: audioInputQueue) {
            while(audioInput.isReadyForMoreMediaData) {
                let sample = assetReaderAudioOutput.copyNextSampleBuffer()
                if let sample = sample {
                    audioInput.append(sample)
                } else {
                    audioInput.markAsFinished()
                    DispatchQueue.main.async {
                        audioFinished = true
                        closeWriter()
                    }
                    break
                }
            }
        }
        
        videoInput.requestMediaDataWhenReady(on: videoInputQueue) {
            //request data here
            while(videoInput.isReadyForMoreMediaData){
                let sample = assetReaderVideoOutput.copyNextSampleBuffer()
                if let sample = sample {
                    videoInput.append(sample)
                } else {
                    videoInput.markAsFinished()
                    DispatchQueue.main.async {
                        videoFinished = true
                        closeWriter()
                    }
                    break
                }
            }
        }
    }
}