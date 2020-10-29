//
//  Constants.swift
//  CatAndDog
//
//  Created by Jason Ou Yang on 2020/7/31.
//  Copyright © 2020 Jason Ou Yang. All rights reserved.
//

import UIKit

struct K {
    struct Color {
        static let backgroundColor = UIColor(named: "backgroundColor")
        static let toolbarItem = UIColor(named: "buttonColor")
    }
    struct SegueIdentifier {
        static let collectionToSingle = "collectionToSingle"
    }
    struct ButtonImage {
        static let heart = UIImage(systemName: "heart")
        static let filledHeart = UIImage(systemName: "heart.fill")
        static let trash = UIImage(systemName: "trash")
        static let share = UIImage(systemName: "square.and.arrow.up")
    }
    struct Data {
        static let initialDataRequestNumber: Int = 6
        static let dataRequestNumber: Int = 1
        static let maxDataNumberStored: Int = 7
    }
    struct ToolBar {
        static let height: CGFloat = 44.0
    }
    struct CardView {
        struct Size {
            static let transform: CGFloat = 0.9
        }
        struct Style {
            static let cornerRadius: CGFloat = 25
            static let backgroundColor = UIColor(named: "cardBackgroundColor")
        }
        struct Constraint {
            static let leading: CGFloat = 10.0
            static let trailing: CGFloat = -10.0
            static let top: CGFloat = 10
            static let bottom: CGFloat = -10
        }
    }
    struct ImageView {
        static let dynamicScaleThreshold: CGFloat = 0.15
        struct Constraint {
            static let leading: CGFloat = 0.0
            static let trailing: CGFloat = -0.0
            static let top: CGFloat = 0.0
            static let bottom: CGFloat = -0.0
        }
    }
}
