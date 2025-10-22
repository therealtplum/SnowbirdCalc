//
//  VCardActivityItemSource.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/21/25.
//


import Foundation
import UniformTypeIdentifiers
import UIKit

// iOS 15 fallback activity item source (explicit UTI)
final class VCardActivityItemSource: NSObject, UIActivityItemSource {
    private let data: Data
    private let filename: String

    init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        Data()
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        data as NSData
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        UTType.vCard.identifier
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        filename
    }
}