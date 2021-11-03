//
//  EmojiArtModel.Background.swift
//  EmojiArt
//
//  Created by Volodymyr Seredovych on 27.10.2021.
//

import Foundation

extension EmojiArt {
    enum Background: Equatable {
        case blank
        case url(URL)
        case imageData(Data)
        
        var url: URL? {
            switch self {
            case .url(let url): return url
            default: return nil
            }
        }
        
        var imageData: Data? {
            switch self {
            case .imageData(let data): return data
            default: return nil
            }
        }
    }
}
