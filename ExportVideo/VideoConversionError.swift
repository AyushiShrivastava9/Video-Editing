//
//  VideoConversionError.swift
//  ExportVideo
//
//  Created by Ayushi on 16/06/21.
//

import Foundation

enum VideoConversionError: Swift.Error {
    case invalidVideoTrack
    case invalidAudioTrack
    case invalidAssetReader
    case invalidAssetWriter
    case invalidVideoOutputReader
    case invalidAudioOutputReader
    case exportFailed(Error)
}
