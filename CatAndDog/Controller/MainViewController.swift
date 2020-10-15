//
//  MainViewController.swift
//  CatAndDog
//
//  Created by Jason Ou Yang on 2020/7/21.
//  Copyright © 2020 Jason Ou Yang. All rights reserved.
//

import UIKit

enum CurrentView {
    case first
    case second
    case undo
}

enum CardBehind {
    case firstCard
    case secondCard
}

class MainViewController: UIViewController, NetworkManagerDelegate {
    
    @IBOutlet weak var toolBar: UIToolbar!
    @IBOutlet weak var favoriteBtn: UIBarButtonItem!
    @IBOutlet weak var shareBtn: UIBarButtonItem!
    @IBOutlet weak var undoBtn: UIBarButtonItem!
    
    var networkManager = NetworkManager()
    let databaseManager = DatabaseManager()
    let firstCard = UIView()
    let secondCard = UIView()
    let imageView1 = UIImageView()
    let imageView2 = UIImageView()
    var cardViewAnchor = CGPoint()
    var dataIndex: Int = 0
    var isInitialImageLoaded: Bool = false
    var isNewDataAvailable: Bool = false
    var isCard1DataAvailable: Bool = false
    var isCard2DataAvailable: Bool = false
    var firstCardData: CatData?
    var secondCardData: CatData?
    var dismissedData: CatData?
    var currentCard: CurrentView = .first
    var currentData: CatData? {
        switch currentCard {
        case .first:
            guard firstCardData != nil else { return nil }
            return firstCardData!
        case .second:
            guard secondCardData != nil else { return nil }
            return secondCardData!
        case .undo:
            guard dismissedData != nil else { return nil }
            return dismissedData!
        }
    }
    var cardBelowUndoCard: CardBehind?
    var dismissedCardPosition: CGPoint?
    var dismissedCardTransform: CGAffineTransform?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        networkManager.delegate = self
        toolBar.heightAnchor.constraint(equalToConstant: K.ToolBar.height).isActive = true // define toolBar's height
        fetchNewData(initialRequest: true) // initiate data downloading

        // Add cardView, ImageView and implement neccesary constraints
        view.addSubview(firstCard)
        view.insertSubview(secondCard, belowSubview: firstCard)
        firstCard.addSubview(imageView1)
        secondCard.addSubview(imageView2)
        
        addCardViewConstraint(cardView: firstCard)
        addCardViewConstraint(cardView: secondCard)
        secondCard.transform = CGAffineTransform(scaleX: K.CardView.Size.transform, y: K.CardView.Size.transform)
        addImageViewConstraint(imageView: imageView1, constrainTo: firstCard)
        addImageViewConstraint(imageView: imageView2, constrainTo: secondCard)
        
        databaseManager.createDirectory() // Create folder for local image files store
        databaseManager.loadImages() // Load up data saved in user's device
        
        // Disable toolbar buttons before data is downloaded
        favoriteBtn.isEnabled = false
        shareBtn.isEnabled = false
        
        // TEST AREA
        undoBtn.isEnabled = false
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh favorite button's image
        if let currentUsedData = currentData {
            let isDataSaved = databaseManager.isDataSaved(data: currentUsedData)
            DispatchQueue.main.async {
                self.favoriteBtn.image = isDataSaved ? K.ButtonImage.filledHeart : K.ButtonImage.heart
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Save the center position of the created card view
        cardViewAnchor = firstCard.center
    }
    
    //MARK: - Activity Indicator
    
    let indicator1 = UIActivityIndicatorView()
    let indicator2 = UIActivityIndicatorView()
    
    // indicator is placed right at the center of the cardView
    private func addIndicatorConstraint(indicator: UIActivityIndicatorView, constraintTo imageView: UIImageView) {
        let imageViewMargins = imageView.layoutMarginsGuide
        indicator.centerXAnchor.constraint(equalTo: imageViewMargins.centerXAnchor).isActive = true
        indicator.centerYAnchor.constraint(equalTo: imageViewMargins.centerYAnchor).isActive = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        // style
        indicator.style = .large
        indicator.hidesWhenStopped = true
    }
    
    private func addIndicator(to cardView: UIView) {
        switch cardView {
        case firstCard:
            imageView1.addSubview(indicator1)
            addIndicatorConstraint(indicator: indicator1, constraintTo: imageView1)
            indicator1.startAnimating()
        case secondCard:
            imageView2.addSubview(indicator2)
            addIndicatorConstraint(indicator: indicator2, constraintTo: imageView2)
            indicator2.startAnimating()
        default:
            return
        }
        
    }
    
    //MARK: - Undo Action
    
    @IBAction func undoButtonPressed(_ sender: UIBarButtonItem) {
        undoBtn.isEnabled = false
        
        // Disable current card's gesture recognizer and save its UIView
        switch currentCard {
        case .first:
            if let firstCardGR = firstCard.gestureRecognizers?.first {
                firstCardGR.isEnabled = false
            }
            cardBelowUndoCard = .firstCard
        case .second:
            if let secondCardGR = secondCard.gestureRecognizers?.first {
                secondCardGR.isEnabled = false
            }
            cardBelowUndoCard = .secondCard
        case .undo:
            print("Error: Undo button should have not been enabled")
        }
        
        let undoCard = UIView()
        let undoImageView = UIImageView()
        view.addSubview(undoCard)
        undoCard.addSubview(undoImageView)
        addCardViewConstraint(cardView: undoCard)
        addImageViewConstraint(imageView: undoImageView, constrainTo: undoCard)
        
        // position and rotation
        if let originalPosition = dismissedCardPosition, let originalTransform = dismissedCardTransform {
            undoCard.center = originalPosition
            undoCard.transform = originalTransform
        }
        
        
        UIView.animate(withDuration: 0.5) {
            undoCard.center = self.cardViewAnchor
            undoCard.transform = .identity
            switch self.currentCard {
            case .first:
                self.firstCard.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            case .second:
                self.secondCard.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            case .undo:
                print("Error: Undo button should have not been enabled")
            }
        } completion: { (true) in
            if true {
                let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.panGestureHandler))
                undoCard.addGestureRecognizer(panGesture)
                self.currentCard = .undo
            }
        }

    }
    
    //MARK: - Favorite Action
    
    @IBAction func favoriteButtonPressed(_ sender: UIBarButtonItem) {
        if let currentUsedData = currentData {
            let isDataSaved = databaseManager.isDataSaved(data: currentUsedData)
            
            // Save data if it's absent in database, otherwise delete data in database
            if isDataSaved == false {
                databaseManager.saveData(currentUsedData)
                DispatchQueue.main.async {
                    self.favoriteBtn.image = K.ButtonImage.filledHeart
                }
            } else if isDataSaved == true {
                // delete file in database
                databaseManager.deleteData(id: currentUsedData.id)
                
                DispatchQueue.main.async {
                    self.favoriteBtn.image = K.ButtonImage.heart
                }
            }
        }
    }
    
    //MARK: - Share Action
    
    @IBAction func shareButtonPressed(_ sender: UIBarButtonItem) {
        if let imageToShare = currentData?.image {
            let activityController = UIActivityViewController(activityItems: [imageToShare], applicationActivities: nil)
            present(activityController, animated: true)
        }
    }
    
    //MARK: - Constraints Implementation
    
    // Add constraints to cardView
    private func addCardViewConstraint(cardView: UIView) {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        let viewMargins = self.view.layoutMarginsGuide
        let toolbarMargins = self.toolBar.layoutMarginsGuide
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: viewMargins.leadingAnchor, constant: K.CardView.Constraint.leading),
            cardView.trailingAnchor.constraint(equalTo: viewMargins.trailingAnchor, constant: K.CardView.Constraint.trailing),
            cardView.topAnchor.constraint(equalTo: viewMargins.topAnchor, constant: K.CardView.Constraint.top),
            cardView.bottomAnchor.constraint(equalTo: toolbarMargins.topAnchor, constant: K.CardView.Constraint.bottom)
        ])
        
        // Style
        cardView.backgroundColor = K.CardView.Style.backgroundColor
        cardView.layer.cornerRadius = K.CardView.Style.cornerRadius
        
        // Shadow
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.2
        cardView.layer.shadowOffset = .zero
        cardView.layer.shadowRadius = 5
        cardView.layer.shouldRasterize = true
        cardView.layer.rasterizationScale = UIScreen.main.scale
    }
    
    // Add constraints to imageView
    private func addImageViewConstraint(imageView: UIImageView, constrainTo cardView: UIView) {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: K.ImageView.Constraint.top),
            imageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: K.ImageView.Constraint.leading),
            imageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: K.ImageView.Constraint.trailing),
            imageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: K.ImageView.Constraint.bottom)
        ])
        
        // Style
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 20
        imageView.clipsToBounds = true
    }
    
    //MARK: - Data Fetching & Updating
    
    private func fetchNewData(initialRequest: Bool) {
        // first time requesting image data
        if initialRequest {
            networkManager.performRequest(imageDownloadNumber: K.Data.initialDataRequestNumber)
            addIndicator(to: firstCard)
        } else {
            networkManager.performRequest(imageDownloadNumber: K.Data.dataRequestNumber)
        }
    }

    // Update UI using new data
    internal func dataDidFetch() {
        let dataSet = networkManager.serializedData
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureHandler))
        
        // update first cardView with first fetched data
        if dataIndex == 0 {
            if let firstData = dataSet[dataIndex + 1] {
                isNewDataAvailable = true
                isCard1DataAvailable = true
                firstCardData = firstData
                
                // Determine if downloaded data already exist in database
                let isDataSaved = databaseManager.isDataSaved(data: firstData)
                
                DispatchQueue.main.async {
                    self.imageView1.image = firstData.image
                    self.indicator1.stopAnimating()
                    
                    // Enable toolbar buttons
                    self.favoriteBtn.isEnabled = true // enable favorite button
                    self.shareBtn.isEnabled = true
                    
                    // Set button's image as a filled heart indicating data is already in database
                    if isDataSaved == true {
                        self.favoriteBtn.image = K.ButtonImage.filledHeart
                    }
                    // Add UIPanGestureRecognizer to the first card
                    self.firstCard.addGestureRecognizer(panGesture)
                }
                dataIndex += 1
            }
        } else if dataIndex == 1 {
            if let secondData = dataSet[dataIndex + 1] {
                
                isCard2DataAvailable = true
                secondCardData = secondData
                
                DispatchQueue.main.async {
                    self.imageView2.image = secondData.image
                    self.indicator2.stopAnimating()
                    
                    // Add pan gesture recognizer to second card and disable it
                    self.secondCard.addGestureRecognizer(panGesture)
                    if let secondCardGR = self.secondCard.gestureRecognizers?.first {
                        secondCardGR.isEnabled = false
                    }
                }
                dataIndex += 1
            }
        }
        // Update UI if new data was not available in the previous UI updating session
        if isNewDataAvailable == false {
            updateCardView()
        }
    }
    
    //MARK: - Card Animation & Rotation Section
    
    /// Handling the cardView's panning effect which is responded to user's input via finger dragging on the cardView itself.
    /// - Parameter sender: A concrete subclass of UIGestureRecognizer that looks for panning (dragging) gestures.
    @objc func panGestureHandler(_ sender: UIPanGestureRecognizer) {
        guard let card = sender.view else { return }
        
        let halfViewWidth = view.frame.width / 2
        
        // Point of the finger in the view's coordinate system
        let fingerMovement = sender.translation(in: view)
        
        // Amount of x-axis offset the card moved from its original position
        let xAxisOffset = card.center.x - cardViewAnchor.x
        
        // 1.0 Radian = 180º
        let rotationAtMax: CGFloat = 1.0
        let cardRotationRadian = (rotationAtMax / 3) * (xAxisOffset / halfViewWidth)
        
        // Card move to where the user's finger is
        card.center = CGPoint(x: cardViewAnchor.x + fingerMovement.x, y: cardViewAnchor.y + fingerMovement.y)
        
        // Card's rotation increase when it approaches the side edge of the screen
        card.transform = CGAffineTransform(rotationAngle: cardRotationRadian)
        
        // Revert the card view behind to its original size as the current view is moved away from its original position
        var xOffset: CGFloat {
            if abs(xAxisOffset) <= halfViewWidth {
                return abs(xAxisOffset) / halfViewWidth
            } else {
                return 1
            }
        }
        
        // Change the size of the card behind
        let transform = K.CardView.Size.transform
        
        switch currentCard {
        case .first:
            secondCard.transform = CGAffineTransform(
                scaleX: transform + (xOffset * (1 - transform)),
                y: transform + (xOffset * (1 - transform))
            )
        case .second:
            firstCard.transform = CGAffineTransform(
                scaleX: transform + (xOffset * (1 - transform)),
                y: transform + (xOffset * (1 - transform))
            )
        case .undo:
            guard cardBelowUndoCard != nil else { return }
            switch cardBelowUndoCard! {
            case .firstCard:
                firstCard.transform = CGAffineTransform(
                    scaleX: transform + (xOffset * (1 - transform)),
                    y: transform + (xOffset * (1 - transform))
                )
            case .secondCard:
                secondCard.transform = CGAffineTransform(
                    scaleX: transform + (xOffset * (1 - transform)),
                    y: transform + (xOffset * (1 - transform))
                )
            }
        }
        
        // When user's finger left the screen
        if sender.state == .ended {
            /*
             Card can only be dismissed when it's dragged to the side of the screen
             and the current image view's image is available
             */
            let releasePoint = CGPoint(x: card.frame.midX, y: card.frame.midY)
            
            if card.center.x < halfViewWidth / 2 && currentData != nil { // card was at the left side of the screen
                dismissedData = currentData!
                animateCard(card, releasedPoint: releasePoint)
            }
            else if card.center.x > halfViewWidth * 3/2 && currentData != nil { // card was at the right side of the screen
                dismissedData = currentData!
                animateCard(card, releasedPoint: releasePoint)
            }
            // Reset card's position and rotation state
            else {
                UIView.animate(withDuration: 0.2) {
                    card.center = self.cardViewAnchor
                    card.transform = CGAffineTransform.identity
                    
                    // Revert the size of the card view behind
                    switch self.currentCard {
                    case .first:
                        self.secondCard.transform = CGAffineTransform(
                            scaleX: K.CardView.Size.transform,
                            y: K.CardView.Size.transform
                        )
                    case .second:
                        self.firstCard.transform = CGAffineTransform(
                            scaleX: K.CardView.Size.transform,
                            y: K.CardView.Size.transform
                        )
                    case .undo:
                        guard self.cardBelowUndoCard != nil else { return }
                        switch self.cardBelowUndoCard! {
                        case .firstCard:
                            self.firstCard.transform = CGAffineTransform(
                                scaleX: K.CardView.Size.transform,
                                y: K.CardView.Size.transform
                            )
                        case .secondCard:
                            self.secondCard.transform = CGAffineTransform(
                                scaleX: K.CardView.Size.transform,
                                y: K.CardView.Size.transform
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func animateCard(_ card: UIView, releasedPoint: CGPoint) {
        enum Quadrant {
            case first
            case second
            case third
            case forth
            case none
        }
        // Determine the quarant of the release point
        var quadrant: Quadrant?
        let releasePointX = releasedPoint.x
        let releasePointY = releasedPoint.y
        let anchorX = cardViewAnchor.x
        let anchorY = cardViewAnchor.y
        
        if releasePointX > anchorX && releasePointY < anchorY {
            quadrant = .first
        } else if releasePointX <= anchorX && releasePointY < anchorY {
            quadrant = .second
        } else if releasePointX <= anchorX && releasePointY >= anchorY {
            quadrant = .third
        } else if releasePointX > anchorX && releasePointY >= anchorY {
            quadrant = .forth
        }
        
        // Move the card to the edge of either side of the screen depending on where the card was released at
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            guard quadrant != nil else { return }
            let offsetAmount = UIScreen.main.bounds.width
            switch quadrant! {
            case .first:
                card.center = CGPoint(x: card.center.x + offsetAmount, y: card.center.y - offsetAmount)
            case .second:
                card.center = CGPoint(x: card.center.x - offsetAmount, y: card.center.y - offsetAmount)
            case .third:
                card.center = CGPoint(x: card.center.x - offsetAmount, y: card.center.y + offsetAmount)
            case .forth:
                card.center = CGPoint(x: card.center.x + offsetAmount, y: card.center.y + offsetAmount)
            case .none:
                card.center = CGPoint(x: card.center.x + offsetAmount, y: card.center.y + offsetAmount)
            }
        } completion: { (true) in
            if true {
                self.dismissedCardPosition = card.center
                self.dismissedCardTransform = card.transform
                
                // Disable gesture recognizer
                if let cardGR = card.gestureRecognizers?.first {
                    cardGR.isEnabled = false
                }
                card.removeFromSuperview()
                
                if self.currentCard != .undo {
                    card.transform = CGAffineTransform.identity
                    self.rotateCard(dismissedView: card)
                } else if self.currentCard == .undo {
                    
                    // Enable the card's GR after undo card is dismissed
                    guard self.cardBelowUndoCard != nil else { return }
                    switch self.cardBelowUndoCard! {
                    case .firstCard:
                        self.firstCard.gestureRecognizers?.first?.isEnabled = true
                        self.currentCard = .first
                    case .secondCard:
                        self.secondCard.gestureRecognizers?.first?.isEnabled = true
                        self.currentCard = .second
                    }
                }
                // Re-enable undo button
                self.undoBtn.isEnabled = true
            }
        }
    }
        
    func rotateCard(dismissedView: UIView) {
        /*
         1. Update favorite button's status
         2. Place the dismissed card beneath the current cardView
         3. Set up dismissed card's position and constraint
         4. Update imageView's image
         5. Fetch new data
         6. Enable gesture recognizer
        */
        if dismissedView == firstCard { // dismissed card is firstCard
            currentCard = .second
            if let cardGR = secondCard.gestureRecognizers?.first {
                cardGR.isEnabled = true
            }
            
            // Favorite button is enabled if data is available
            favoriteBtn.isEnabled = isCard2DataAvailable ? true : false
            if let card2Data = secondCardData {
                let isDataSaved = databaseManager.isDataSaved(data: card2Data) // determine whether data is already in database
                favoriteBtn.image = isDataSaved ? K.ButtonImage.filledHeart : K.ButtonImage.heart
            }
            
            // Put the dismissed card behind the current card
            self.view.insertSubview(dismissedView, belowSubview: secondCard)
            dismissedView.center = cardViewAnchor
            addCardViewConstraint(cardView: dismissedView)
            
            // Shrink the size of the newly added card view
            dismissedView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            
            updateCardView()
            fetchNewData(initialRequest: false)
        } else if dismissedView == secondCard { // dismissed card is secondCard
            currentCard = .first
            if let cardGR = firstCard.gestureRecognizers?.first {
                cardGR.isEnabled = true
            }
            
            // Favorite button is enabled if data is available
            favoriteBtn.isEnabled = isCard1DataAvailable ? true : false
            if let card1Data = firstCardData {
                let isDataSaved = databaseManager.isDataSaved(data: card1Data) // Determine whether data is already in database
                favoriteBtn.image = isDataSaved ? K.ButtonImage.filledHeart : K.ButtonImage.heart
            }
            
            // Put the dismissed card behind the current card
            self.view.insertSubview(dismissedView, belowSubview: firstCard)
            dismissedView.center = cardViewAnchor
            addCardViewConstraint(cardView: dismissedView)
            
            // Shrink the size of the newly added card view
            dismissedView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            
            updateCardView()
            fetchNewData(initialRequest: false)
        } else {
            print("Error: The dismissed card is neither firstCard nor secondCard")
        }
    }
    
    //MARK: - Update Image of imageView
    
    // Prepare the next cardView to be shown
    private func updateCardView() {
        
        let dataSet = networkManager.serializedData
        if let newData = dataSet[dataIndex + 1] { // determine whether new data is available
            
            let newImage = newData.image
            
            // Check to which cardView the data is to be allocated
            if (dataIndex + 1) % 2 == 1 { // new data is for cardView 1
                DispatchQueue.main.async {
                    self.imageView1.image = newImage
                    self.indicator1.stopAnimating()
                }
                dataIndex += 1
                firstCardData = newData
                isCard1DataAvailable = true
            } else { // new data is for cardView 2
                DispatchQueue.main.async {
                    self.imageView2.image = newImage
                    self.indicator2.stopAnimating()
                }
                dataIndex += 1
                secondCardData = newData
                isCard2DataAvailable = true
            }
            
            // set isNewDataAvailable true if next cardView's data is available, vice versa
            if currentCard == .first {
                if secondCardData != nil {
                    isNewDataAvailable = true
                }
            } else if currentCard == .second {
                if firstCardData != nil {
                    isNewDataAvailable = true
                }
            }
        }
        // New data is not available
        else {
            // set both cardViews' UI to loading status if no data is available for both cardViews
            if isNewDataAvailable == false {
                if currentCard == .first {
                    DispatchQueue.main.async {
                        self.imageView2.image = nil
                        self.addIndicator(to: self.secondCard)
                    }
                } else if currentCard == .second {
                    DispatchQueue.main.async {
                        self.imageView1.image = nil
                        self.addIndicator(to: self.firstCard)
                    }
                }
                firstCardData = nil
                secondCardData = nil
            }
            
            isNewDataAvailable = false // trigger method updateCardView to be executed when new data is fetched successfully
            
            // new data for cardView 1 is not available
            if (dataIndex + 1) % 2 == 1 {
                DispatchQueue.main.async {
                    self.imageView1.image = nil
                    self.addIndicator(to: self.firstCard)
                }
                isCard1DataAvailable = false
                firstCardData = nil
            }
            // new data for cardView 2 is not available
            else {
                DispatchQueue.main.async {
                    self.imageView2.image = nil
                    self.addIndicator(to: self.secondCard)
                }
                isCard2DataAvailable = false
                secondCardData = nil
            }
        }
    }
    
    //MARK: - Error Handling Section
    
    // Present error message to the user if any error occurs in the data fetching process
    func errorDidOccur() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Cannot connect to the Internet",
                message: "Signal from Cat Planet is too weak.\n Please check your antenna. 📡",
                preferredStyle: .alert)
            let settingsAction = UIAlertAction(title: "Settings", style: .default) { (_) -> Void in
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
                }
            }
            let cancelAction = UIAlertAction(title: "OK", style: .cancel)
            alert.addAction(settingsAction)
            alert.addAction(cancelAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
}

