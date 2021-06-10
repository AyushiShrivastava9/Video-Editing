//
//  MediaType.swift
//  ExportVideo
//
//  Created by Ayushi on 10/06/21.
//

import AVFoundation

enum MediaType {
    case MP4
    case MOV
    
    func getFileType() -> AVFileType {
        switch self {
        case .MOV:
            return .mov
        case .MP4:
            return .mp4
        }
    }
    
    func fileExtension() -> String {
        switch self {
        case .MOV:
            return "mov"
        case .MP4:
            return "mp4"
        }
    }
}

