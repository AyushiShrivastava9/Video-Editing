//
//  VideoEditor.swift
//  ExportVideo
//
//  Created by Ayushi on 09/06/21.
//

import UIKit
import AVFoundation

final class VideoEditor {
    var assetReader: AVAssetReader?
    var assetWriter: AVAssetWriter?
    
    func export(fromVideoAt videoURL: URL, onComplete: @escaping (URL?) -> Void) {
        // changeFormat(of: videoURL, to: .MP4, completionHandler: onComplete)
         //changeBitrate(url: videoURL, completion: onComplete)
//        trimDuration(of: videoURL,
//                     from: 0,
//                     to: 3,
//                     completion: onComplete)
//        changeResolution(videoUrl: videoURL, presetName: AVAssetExportPresetLowQuality, completion: onComplete)
//        mergeVideos(firstVideoURL: videoURL, secondVideoURL: videoURL, completion: onComplete)
    }
    
    func changeFormat(of videoURL: URL, to type: MediaType, completionHandler: @escaping (URL?) -> Void) {
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
        let outputUrl = outputUrl(for: type)

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
    
    private func changeBitrate(url: URL, completion: @escaping (Result<URL?, VideoConversionError>) -> Void) {
        let outputURL = outputUrl(for: .MOV)
        var audioFinished = false
        var videoFinished = false
        let asset = AVAsset(url: url)
        
        //create asset reader
        do{
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            assetReader = nil
        }
        
        guard let reader = assetReader else {
            // Could not initalize asset reader probably failed its try catch
            completion(.failure(.invalidAssetReader))
            return
        }
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion(.failure(.invalidVideoTrack))
            return
        }
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            completion(.failure(.invalidAudioTrack))
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
            //Couldn't add video output reader
            completion(.failure(.invalidVideoOutputReader))
        }
        
        if reader.canAdd(assetReaderAudioOutput){
            reader.add(assetReaderAudioOutput)
        } else {
            //couldn't add audio output reader
            completion(.failure(.invalidAudioOutputReader))
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
            completion(.failure(.invalidAssetWriter))
            return
        }
        
        writer.shouldOptimizeForNetworkUse = true
        writer.add(videoInput)
        writer.add(audioInput)
        
        
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: .zero)
        
        
        let closeWriter:() -> Void = {
            if (audioFinished && videoFinished) {
                self.assetWriter?.finishWriting(completionHandler: {
                    completion(.success(self.assetWriter?.outputURL))
                })
                self.assetReader?.cancelReading()
            }
        }
        
        
        audioInput.requestMediaDataWhenReady(on: audioInputQueue) {
            while(audioInput.isReadyForMoreMediaData) {
                if let sample = assetReaderAudioOutput.copyNextSampleBuffer() {
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
                if let sample = assetReaderVideoOutput.copyNextSampleBuffer() {
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
    
    func trimDuration(of videoURL: URL, from: TimeInterval, to: TimeInterval, completion: @escaping ((URL?) -> Void)) {
        let asset = AVAsset(url: videoURL)
        
        guard from >= 0, to <= asset.duration.seconds else {
            completion(nil)
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        let preset = AVAssetExportPresetHighestQuality
        let outFileType = AVFileType.mp4
        let outputUrl = outputUrl(for: .MOV)
        
        AVAssetExportSession.determineCompatibility(ofExportPreset: preset,
                                                    with: asset,
                                                    outputFileType: outFileType) { isCompatible in
            guard isCompatible else {
                completion(nil)
                return
            }
            // Compatibility check succeeded, continue with export.
            guard let exportSession = AVAssetExportSession(asset: asset,
                                                           presetName: preset) else {
                completion(nil)
                return
            }
            
            exportSession.outputURL =  outputUrl
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.outputFileType = .mov
            let start = CMTimeMakeWithSeconds(from, preferredTimescale: 600)
            let duration = CMTimeMakeWithSeconds(to - from, preferredTimescale: 600)
            
            
            let range = CMTimeRangeMake(start: start, duration: duration)
            exportSession.timeRange = range
            
            exportSession.exportAsynchronously {
                // Handle export results.
                switch exportSession.status {
                case .failed:
                    print(exportSession.error ?? "NO ERROR")
                    completion(nil)
                case .cancelled:
                    print("Export canceled")
                    completion(nil)
                case .completed:
                    //Video conversion finished
                    print("Successful!")
                    print(exportSession.outputURL ?? "NO OUTPUT URL")
                    completion(exportSession.outputURL)
                case .unknown:
                    print("Export Unknown Error")
                default: break
                }
            }
        }
    }
    
    func changeResolution(videoUrl: URL,
                   presetName: String = AVAssetExportPresetHighestQuality,
                   completion: @escaping ((URL?) -> Void)) {
        let asset = AVAsset(url: videoUrl)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        let outputUrl = outputUrl(for: .MOV)
        
        AVAssetExportSession.determineCompatibility(ofExportPreset: presetName,
                                                    with: asset,
                                                    outputFileType: MediaType.MOV.getFileType()) { isCompatible in
            guard isCompatible else {
                completion(nil)
                return
            }
            // Compatibility check succeeded, continue with export.
            guard let exportSession = AVAssetExportSession(asset: asset,
                                                           presetName: presetName) else {
                completion(nil)
                return
            }
            
            exportSession.outputURL =  outputUrl
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.outputFileType = .mov
            
            exportSession.exportAsynchronously {
                // Handle export results.
                switch exportSession.status {
                case .failed:
                    print(exportSession.error ?? "NO ERROR")
                    completion(nil)
                case .cancelled:
                    print("Export canceled")
                    completion(nil)
                case .completed:
                    //Video conversion finished
                    print("Successful!")
                    print(exportSession.outputURL ?? "NO OUTPUT URL")
                    completion(exportSession.outputURL)
                case .unknown:
                    print("Export Unknown Error")
                default: break
                }
            }
        }
    }
    
    func mergeVideos(firstVideoURL: URL, secondVideoURL: URL, completion: @escaping (URL?) -> Void) {
            let firstAsset = AVAsset(url: firstVideoURL)
            let secondAsset = AVAsset(url: secondVideoURL)
        
        let mixComposition = AVMutableComposition()
        
        // First video and audio
        guard
          let firstTrack = mixComposition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
          else { return }
        
        do {
          try firstTrack.insertTimeRange(
            CMTimeRangeMake(start: .zero, duration: firstAsset.duration), // Can also trim videos here
            of: firstAsset.tracks(withMediaType: .video)[0],
            at: .zero)
        } catch {
          print("Failed to load first track")
          return
        }
        
        guard
          let firstAudioTrack = mixComposition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: 0)
          else { return }
        
        do {
          try firstAudioTrack.insertTimeRange(
            CMTimeRangeMake(start: .zero, duration: firstAsset.duration), // Can also trim videos here
            of: firstAsset.tracks(withMediaType: .audio)[0],
            at: .zero)
        } catch {
          print("Failed to load first audio track")
          return
        }
        
        // Second video and audio
        
        guard
          let secondTrack = mixComposition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
          else { return }
            
        do {
          try secondTrack.insertTimeRange(
            CMTimeRangeMake(start: .zero, duration: secondAsset.duration),
            of: secondAsset.tracks(withMediaType: .video)[0],
            at: firstAsset.duration)
        } catch {
          print("Failed to load second track")
          return
        }
        
        guard
          let secondAudioTrack = mixComposition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: 0)
          else { return }
        
        do {
          try secondAudioTrack.insertTimeRange(
            CMTimeRangeMake(start: .zero, duration: secondAsset.duration), // Can also trim videos here
            of: secondAsset.tracks(withMediaType: .audio)[0],
            at: firstAsset.duration)
        } catch {
          print("Failed to load second audio track")
          return
        }
        
        // Merge both
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(
          start: .zero,
          duration: CMTimeAdd(firstAsset.duration, secondAsset.duration))
        
        let firstInstruction = AVMutableVideoCompositionLayerInstruction(
          assetTrack: firstTrack)
        // first video becomes invisible when second starts
        firstInstruction.setOpacity(0.0, at: firstAsset.duration)
        let secondInstruction = AVMutableVideoCompositionLayerInstruction(
          assetTrack: secondTrack)
        
        mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
        
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = firstTrack.naturalSize // Same video we are merging
        
        let outputURL = outputUrl(for: .MOV)

        AVAssetExportSession.determineCompatibility(ofExportPreset: AVAssetExportPresetHighestQuality,
                                                    with: mixComposition,
                                                    outputFileType: MediaType.MOV.getFileType()) { isCompatible in
            guard isCompatible else { return }
            // Compatibility check succeeded, continue with export.
            guard let exportSession = AVAssetExportSession(
                    asset: mixComposition,
                    presetName: AVAssetExportPresetHighestQuality) else { return }
            exportSession.outputURL = outputURL
            exportSession.outputFileType = MediaType.MOV.getFileType()
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.videoComposition = mainComposition
            exportSession.exportAsynchronously {
                // Handle export results.
                switch exportSession.status {
                case .failed:
                    print(exportSession.error ?? "NO ERROR")
                    completion(nil)
                case .cancelled:
                    print("Export canceled")
                    completion(nil)
                case .completed:
                    //Video conversion finished
                    print("Successful!")
                    print(exportSession.outputURL ?? "NO OUTPUT URL")
                    completion(exportSession.outputURL)
                case .unknown:
                    print("Export Unknown Error")
                default: break
                }
            }
        }
    }
    
    private func outputUrl(for type: MediaType) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        return URL(fileURLWithPath: NSTemporaryDirectory())
          .appendingPathComponent(formatter.string(from: Date()))
            .appendingPathExtension(type.fileExtension())
    }
}
