//
//  Strings.swift
//  CatAndDog
//
//  Created by Jason Ou Yang on 2020/12/17.
//  Copyright © 2020 Jason Ou Yang. All rights reserved.
//

import Foundation

struct Z {
    struct InstructionText {
        static let swipeGesture = NSLocalizedString("CARD_GESTURE", comment: "Hint of card swiping gesture")
        static let buttonInstruction = NSLocalizedString("BUTTON_INSTRUCTION", comment: "Usage of all UI buttons")
        static let bless = NSLocalizedString("BLESS", comment: "Bless the user")
    }
    
    struct AlertMessage {
        struct NetworkError {
            static let alertTitle = NSLocalizedString("NETWORK_ERROR_ALERT_TITLE", comment: "")
            static let alertMessage = NSLocalizedString("NETWORK_ERROR_ALERT_MESSAGE", comment: "")
            static let actionTitle = NSLocalizedString("NETWORK_ERROR_ALERT_ACTION", comment: "")
        }
        
        struct DatabaseError {
            static let alertTitle = NSLocalizedString("DATABASE_ERROR_ALERT_TITLE", comment: "")
            static let alertMessage = NSLocalizedString("DATABASE_ERROR_ALERT_MESSAGE", comment: "")
            static let actionTitle = NSLocalizedString("DATABASE_ERROR_ALERT_ACTION", comment: "")
        }
        
        struct DeleteWarning {
            static let alertTitle = NSLocalizedString("DELETE_WARNING_ALERT_TITLE", comment: "")
            static let actionTitle = NSLocalizedString("DELETE_WARNING_ALERT_ACTION", comment: "")
            static let cancelTitle = NSLocalizedString("DELETE_WARNING_ALERT_CANCEL", comment: "")
        }
    }
    
    struct BackgroundView {
        static let noDataLabel = NSLocalizedString("NO_DATA_LABEL_TEXT", comment: "")
    }
}
