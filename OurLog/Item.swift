//
//  Item.swift
//  OurLog
//
//  Created by 구현모 on 9/21/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
