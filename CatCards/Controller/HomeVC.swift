//
//  HomeVC.swift
//  CatCards
//
//  Created by Jason Ou Yang on 2020/7/21.
//  Copyright © 2020 Jason Ou Yang. All rights reserved.
//

import UIKit
import GoogleMobileAds
import UserNotifications
import AppTrackingTransparency

class HomeVC: UIViewController, NetworkManagerDelegate {
    
    //MARK: - IBOutlet
    
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var toolbarHeight: NSLayoutConstraint!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBOutlet weak var undoButton: UIBarButtonItem!
    @IBOutlet weak var collectionButton: UIBarButtonItem!
    @IBOutlet weak var bannerSpace: UIView!
    @IBOutlet weak var bannerSpaceHeight: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    
    //MARK: - Local Properties
    
    static let shared = HomeVC()
    private let defaults = UserDefaults.standard
    let databaseManager = DatabaseManager()
    private let networkManager = NetworkManager()
    private var cardArray: [Card] = []
    private let onboardData = K.OnboardOverlay.data
    private var navBar: UINavigationBar!
    private var cardIndex: Int = 0
    private var maxCardIndex: Int = 0
    private var adReceived = false
    private var backgroundLayer: CAGradientLayer!
    private var zoomOverlay: UIView!
    private var cardIsBeingPanned = false
    private let hapticManager = HapticManager()
    var showOverlay = true
    
    // Number of cards with cat images the user has seen
    private var viewCount: Int = 0 {
        didSet {
            saveViewCount()
        }
    }
    
    private var onboardCompleted = false {
        didSet {
            defaults.setValue(onboardCompleted, forKey: K.UserDefaultsKeys.onboardCompleted)
        }
    }
    
    private var currentCard: Card? {
        if !cardArray.isEmpty && cardIndex < cardArray.count {
            return cardArray[cardIndex]
        } else {
            return nil
        }
    }
    
    private var previousCard: Card? {
        let previoudCardIndex = cardIndex - 1
        if previoudCardIndex >= 0 && previoudCardIndex < cardArray.count {
            return cardArray[cardIndex - 1]
        } else {
            return nil
        }
    }
    
    private var nextCard: Card? {
        let nextCardIndex = cardIndex + 1
        if nextCardIndex > 0 && nextCardIndex < cardArray.count {
            return cardArray[nextCardIndex]
        } else {
            return nil
        }
    }
    
    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panHandler))
        pan.delegate = self
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        return pan
    }()
    
    private lazy var pinchGestureRecognizer: UIPinchGestureRecognizer = {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(zoomHandler))
        pinch.delegate = self
        return pinch
    }()
    
    private lazy var twoFingerPanGestureRecognizer: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(twoFingerPanHandler))
        pan.delegate = self
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        return pan
    }()
    
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapHandler))
        tap.delegate = self
        
        return tap
    }()
    
    private lazy var adBannerView: GADBannerView = {
        // Initialize ad banner
        let adBannerView = GADBannerView(adSize: kGADAdSizeSmartBannerPortrait) // Define ad banner's size
        adBannerView.adUnitID = K.Banner.adUnitID
        adBannerView.rootViewController = self
        adBannerView.delegate = self
        
        return adBannerView
    }()
    
    //MARK: - View Overriding Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navBar = self.navigationController?.navigationBar // Save the reference of the built-in navigation bar
        databaseManager.delegate = self
        networkManager.delegate = self
        
        // Load viewCount value from UserDefaults if there's any
        let savedViewCount = defaults.integer(forKey: K.UserDefaultsKeys.viewCount)
        viewCount = (savedViewCount != 0) ? savedViewCount : 0
        
        // Notify this VC that if the app enters the background, save the cached view count value to UserDefaults.
        NotificationCenter.default.addObserver(self, selector: #selector(saveViewCount), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Show onboarding tutorial and hide toolbar if the user is a new comer
        onboardCompleted = defaults.bool(forKey: K.UserDefaultsKeys.onboardCompleted)
        if !onboardCompleted {
            hideUIButtons()
        }
        
        // Create local image folder in file system and/or load data from it
        databaseManager.createNecessaryFolders()
        databaseManager.getSavedImageFileURLs()
        
        fetchNewData(initialRequest: true) // initiate data downloading
        
        setDownsampleSize() // Prepare ImageProcess's operation parameter
        addBackgroundLayer() // Add gradient color layer to background
        addShadeOverlay() // Add overlay view to be used when card is being zoomed in
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshButtonState()
        setBarStyle()
        backgroundLayer.frame = view.bounds
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { _ in
            self.backgroundLayer.frame = self.view.bounds
            if self.adReceived {
                // Request another banner ad if the orientation of the screen is changing
                self.updateBannerViewSize(bannerView: self.adBannerView)
                self.requestBannerAd()
            }
        }
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // Remove notif. observer to avoid sending notification to invalid obj.
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    //MARK: - Data Fetch & Cache Methods
    
    private func fetchNewData(initialRequest: Bool) {
        switch initialRequest {
        case true:
            networkManager.performRequest(numberOfRequests: K.Data.cacheDataNumber)
        case false:
            networkManager.performRequest(numberOfRequests: 1)
        }
    }
    
    // Create and add a new card to the card array
    func dataDidFetch(data: CatData, dataIndex: Int) {
        DispatchQueue.main.async {
            let cardType: Card.CardType = !self.onboardCompleted && dataIndex < self.onboardData.count ? .onboard : .regular
            let newCard = Card(data: data, index: dataIndex, type: cardType)
            self.cardArray.append(newCard)
            
            // Add the card to the view if it's the last card in the card array
            if self.cardIndex == self.cardArray.count - 1 {
                self.addCardToView(newCard, atBottom: false)
                
                // Introduce the card by animating the change of the card size
                newCard.setSize(status: .intro)
                UIView.animate(withDuration: 0.3) {
                    newCard.transform = .identity
                } completion: { _ in
                    self.attachGestureRecognizers(to: newCard)
                    self.refreshButtonState()
                    
                    // Update the number of cards viewed by the user
                    if self.onboardCompleted {
                        self.viewCount += 1
                    }
                }
            }
            
            // Add the card to the view if it's the next card
            if newCard.index == self.cardIndex + 1 {
                // Introduce the card by animating the change of the card size
                self.addCardToView(newCard, atBottom: true)
                newCard.setSize(status: .intro)
                UIView.animate(withDuration: 0.3) {
                    newCard.setSize(status: .standby)
                }
            }
        }
    }
    
    //MARK: - Card Introduction & Constraint
    
    private func addCardToView(_ card: Card, atBottom: Bool) {
        cardView.addSubview(card)
        addCardConstraint(card)
        card.updateImage()
        
        if atBottom {
            cardView.sendSubviewToBack(card)
            card.setSize(status: .standby)
        }
        
        if !onboardCompleted && card.index == onboardData.count {
            // Show UI buttons when the last onboarding card is showned to user
            showUIButtons()
        }
    }
    
    private func addCardConstraint(_ card: Card) {
        let centerXAnchor = card.centerXAnchor.constraint(equalTo: cardView.centerXAnchor)
        let centerYAnchor = card.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        let heightAnchor = card.heightAnchor.constraint(equalTo: cardView.heightAnchor, multiplier: 0.90)
        let widthAnchor = card.widthAnchor.constraint(equalTo: cardView.widthAnchor, multiplier: 0.90)
        
        // Save constraints to the card's property for manipulation in the future
        card.centerXConstraint = centerXAnchor
        card.centerYConstraint = centerYAnchor
        card.heightConstraint = heightAnchor
        card.widthConstraint = widthAnchor
        
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.centerXConstraint, card.centerYConstraint, card.heightConstraint, card.widthConstraint
        ])
    }
    
    //MARK: - Background & Shading Control
    
    private func setBackgroundColor() {
        let interfaceStyle = traitCollection.userInterfaceStyle
        let lightModeColors = [K.Color.lightModeColor1, K.Color.lightModeColor2]
        let darkModeColors = [K.Color.darkModeColor1, K.Color.darkModeColor2]
        
        backgroundLayer.colors = (interfaceStyle == .light) ? lightModeColors : darkModeColors
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Make background color respond to change of interface style
        setBackgroundColor()
    }
    
    private func addBackgroundLayer() {
        backgroundLayer = CAGradientLayer()
        backgroundLayer.frame = view.bounds
        setBackgroundColor()
        view.layer.insertSublayer(backgroundLayer, at: 0)
    }
    
    private func addShadeOverlay() {
        zoomOverlay = UIView(frame: view.bounds)
        zoomOverlay.backgroundColor = .black
        zoomOverlay.alpha = 0
        view.insertSubview(zoomOverlay, belowSubview: cardView)
    }
    
    //MARK: - Button Status
    
    /// Disable and hide button items in nav-bar and toolbar
    private func hideUIButtons() {
        // Hide navBar button
        navBar.tintColor = .clear
        collectionButton.isEnabled = false
        
        // Hide and disable toolbar buttons
        toolbar.alpha = 0
        shareButton.isEnabled = false
        undoButton.isEnabled = false
        saveButton.isEnabled = false
    }
    
    private func showUIButtons() {
        navBar.tintColor = K.Color.tintColor
        toolbar.alpha = 1
    }
    
    //MARK: - Advertisement Methods
    
    private func loadBannerAd() {
        // Request an ad for the adaptive ad banner.
        DispatchQueue.main.async {
            self.adBannerView.load(GADRequest())
        }
    }
    
    /// Google recommend waiting for the completion callback prior to loading ads,
    /// so that if the user grants the App Tracking Transparency permission,
    /// the Google Mobile Ads SDK can use the IDFA in ad requests.
    @available(iOS 14, *)
    private func requestIDFA() {
        ATTrackingManager.requestTrackingAuthorization { (status) in
            // Tracking authorization completed. Start loading ads here.
            self.loadBannerAd()
        }
    }
    
    private func requestBannerAd() {
        if #available(iOS 14, *) {
            requestIDFA()
        } else {
            loadBannerAd()
        }
    }
    
    /// Place the banner at the center of the reserved ad space
    private func addBannerToBannerSpace(_ bannerView: GADBannerView) {
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerSpace.addSubview(bannerView)
        
        // Define center position only. Width and height is defined later.
        NSLayoutConstraint.activate([
            bannerView.centerYAnchor.constraint(equalTo: bannerSpace.centerYAnchor),
            bannerView.centerXAnchor.constraint(equalTo: bannerSpace.centerXAnchor)
        ])
    }
    
    private func updateBannerViewSize(bannerView: GADBannerView) {
        // Banner's width equals the safe area's width
        let frame = { () -> CGRect in
            // Here safe area is taken into account, hence the view frame is used
            // after the view has been laid out.
            if #available(iOS 11.0, *) {
                return view.frame.inset(by: view.safeAreaInsets)
            } else {
                return view.frame
            }
        }()
        let viewWidth = frame.size.width
        
        // With adaptive banner, height of banner is based on the width of the banner itself
        // Get Adaptive GADAdSize and set the ad view.
        // Here the current interface orientation is used. If the ad is being preloaded
        // for a future orientation change or different orientation, the function for the
        // relevant orientation should be used.
        bannerView.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)
        // Set the height of the reserved ad space the same as the adaptive banner's height
        bannerSpaceHeight.constant = bannerView.frame.height
        
        UIView.animate(withDuration: 0.5) {
            self.updateLayout() // Animate the update of bannerSpace's height
        }
    }
    
    //MARK: - Support Methods
    
    /// Save the value of card view count to user defaults
    @objc func saveViewCount() {
        defaults.setValue(viewCount, forKey: K.UserDefaultsKeys.viewCount)
    }
    
    /// Determine the downsample size of image by calculating the thumbnail's width footprint on the user's device
    private func setDownsampleSize() {
        // Device with wider screen (iPhone Plus and Max series) has one more cell per row than other devices
        let screenWidth = UIScreen.main.bounds.width
        let wideScreenWidth: CGFloat = 414 // Point width of iPhone Plus or Max series
        let cellsPerRow: CGFloat = (screenWidth >= wideScreenWidth) ? 4.0 : 3.0
        let cellSpacing: CGFloat = 1.5 // Space between each cell
        
        // Floor the calculated width to remove any decimal number
        let cellWidth = floor((screenWidth - (cellSpacing * (cellsPerRow - 1))) / cellsPerRow)
        
        let cellSize = CGSize(width: cellWidth, height: cellWidth)
        databaseManager.imageProcess.cellSize = cellSize
    }
    
    /// Hide navigation bar and toolbar's border line
    private func setBarStyle() {
        // Make background of navBar and toolbar transparent
        navBar.setBackgroundImage(UIImage(), for: .default)
        navBar.shadowImage = UIImage()
        toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        toolbar.setShadowImage(UIImage(), forToolbarPosition: .bottom)
    }
    
    //MARK: - Toolbar Button Method and State Control
    
    // Undo Action
    @IBAction func undoButtonPressed(_ sender: UIBarButtonItem) {
        guard !cardIsBeingPanned else { return }
        
        // Make sure data is available for the undo card
        guard previousCard?.data != nil else { return }
        
        hapticManager.prepareImpactGenerator(style: .medium)
        maxCardIndex = cardIndex // Save the current index
        undoButton.isEnabled = false
        hapticManager.impactHaptic?.impactOccurred()
        
        // Remove the next card's data and from the superview
        nextCard?.removeFromSuperview()
        
        let undoCard = cardArray[cardIndex - 1]
        addCardToView(undoCard, atBottom: false)
        undoCard.centerXConstraint.constant = 0
        undoCard.centerYConstraint.constant = 0
        
        UIView.animate(withDuration: 0.5) {
            self.currentCard?.setSize(status: .standby)
            self.updateLayout()
            undoCard.transform = .identity
        } completion: { _ in
            self.attachGestureRecognizers(to: undoCard)
            self.cardIndex -= 1
            DispatchQueue.main.async {
                self.refreshButtonState()
            }
            self.hapticManager.releaseImpactGenerator()
        }
    }
    
    // Data Saving Method
    @IBAction func saveButtonPressed(_ sender: UIBarButtonItem) {
        guard !cardIsBeingPanned else { return }
        
        if let data = currentCard?.data {
            hapticManager.prepareImpactGenerator(style: .soft)
            hapticManager.prepareNotificationGenerator()
            
            // Save data if it's absent in database, otherwise delete it.
            let isSaved = databaseManager.isDataSaved(data: data)
            
            switch isSaved {
            case false:
                databaseManager.saveData(data) { success in
                    if success {
                        // Data is saved successfully
                        DispatchQueue.main.async {
                            self.showConfirmIcon()
                        }
                        hapticManager.notificationHaptic?.notificationOccurred(.success)
                    } else {
                        // Data is not saved successfully
                        hapticManager.notificationHaptic?.notificationOccurred(.error)
                    }
                }
            case true:
                databaseManager.deleteData(id: data.id)
                hapticManager.impactHaptic?.impactOccurred()
            }
            
            refreshButtonState()
            hapticManager.releaseImpactGenerator()
            hapticManager.releaseNotificationGenerator()
        }
    }
    
    // Image Sharing Method
    @IBAction func shareButtonPressed(_ sender: UIBarButtonItem) {
        let catData = currentCard?.data
        guard !cardIsBeingPanned, catData != nil else { return }
        
        // Create and save the cache image file to cache folder
        guard let imageURL = databaseManager.getImageTempURL(catData: catData!) else { return }
        
        hapticManager.prepareImpactGenerator(style: .soft)

        let activityVC = UIActivityViewController(activityItems: [imageURL], applicationActivities: nil)
        
        // Set up Popover Presentation Controller's barButtonItem for iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityVC.popoverPresentationController?.barButtonItem = sender
        }
        
        self.present(activityVC, animated: true)
        
        hapticManager.impactHaptic?.impactOccurred()
        
        // Delete the cache image file after the activityVC is dismissed
        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
            self.databaseManager.removeFile(atDirectory: .cachesDirectory, withinFolder: K.Image.FolderName.cacheImage, fileName: catData!.id)
            
            self.hapticManager.releaseImpactGenerator()
        }
    }
    
    /// Update the toolbar buttons' state
    private func refreshButtonState() {
        guard onboardCompleted && !cardArray.isEmpty else { return }
        
        if currentCard?.data != nil {
            saveButton.isEnabled = true
            shareButton.isEnabled = true
        } else {
            saveButton.isEnabled = false
            shareButton.isEnabled = false
        }
        
        undoButton.isEnabled = (cardIndex > 0 && previousCard?.data != nil) ? true : false
        
        // Toggle the status of save button
        if let data = currentCard?.data {
            let isDataSaved = databaseManager.isDataSaved(data: data)
            saveButton.image = isDataSaved ? K.ButtonImage.filledHeart : K.ButtonImage.heart
        }
    }
    
    private func showConfirmIcon() {
        guard let card = currentCard else { return }
        let confirmView = ConfirmationView(parentView: card, confirmImage: K.Image.savedFeedbackImage)
        confirmView.startAnimation(withDelay: nil, duration: 0.4)
    }
    
    //MARK: - Gesture Recognizers
    
    private enum Side {
        case upper, lower
    }
    
    private var firstFingerLocation: Side?
    
    var startingCenterX: CGFloat = 0
    var startingCenterY: CGFloat = 0
    var startingTransform: CGAffineTransform = .identity
    
    /// Handling the cardView's panning effect which is responded to user's input via finger dragging on the cardView itself.
    /// - Parameter sender: A concrete subclass of UIGestureRecognizer that looks for panning (dragging) gestures.
    @objc private func panHandler(_ sender: UIPanGestureRecognizer) {
        guard let card = sender.view as? Card else { return }
        
        let halfViewWidth = view.frame.width / 2
        
        // Point of the finger in the view's coordinate system
        let fingerPosition = sender.location(in: sender.view)
        let side: Side = fingerPosition.y < card.frame.midY ? .upper : .lower
        // Save which side of the card the finger is placed
        firstFingerLocation = (firstFingerLocation == nil) ? side : firstFingerLocation
        
        let translation = sender.translation(in: view)
        
        // Amount of x-axis offset the card moved from its original position
        let xAxisOffset = card.centerXConstraint.constant
        
        // 1.0 Radian = 180º
        let rotationAtMax: CGFloat = 1.0
        let rotationDegree = (rotationAtMax / 5) * (xAxisOffset / halfViewWidth)
        guard firstFingerLocation != nil else { return }
        // Card's rotation direction is based on the finger position on the card
        let cardRotationRadian = (firstFingerLocation! == .upper) ? rotationDegree : -rotationDegree
        let velocity = sender.velocity(in: self.view) // points per second
        
        // Card's offset of x and y position
        let offset = CGPoint(x: card.centerXConstraint.constant, y: card.centerYConstraint.constant)
        
        // Distance of card's center to its origin point
        let panDistance = hypot(offset.x, offset.y)
        
        switch sender.state {
        case .began:
            startingCenterX = card.centerXConstraint.constant
            startingCenterY = card.centerYConstraint.constant
            startingTransform = card.transform
            
            cardIsBeingPanned = true
        case .changed:
            // Card move to where the user's finger is
            card.centerXConstraint.constant = startingCenterX + translation.x
            card.centerYConstraint.constant = startingCenterY + translation.y
            updateLayout()
            
            // Card's rotation increase when it approaches the side edge of the screen
            card.transform = startingTransform.concatenating(CGAffineTransform(rotationAngle: cardRotationRadian))
            
            // Set next card's transform based on current card's travel distance
            let distance = (panDistance <= halfViewWidth) ? (panDistance / halfViewWidth) : 1
            let defaultScale = K.Card.SizeScale.standby
            
            nextCard?.transform = CGAffineTransform(
                scaleX: defaultScale + (distance * (1 - defaultScale)),
                y: defaultScale + (distance * (1 - defaultScale))
            )
            
        // When user's finger left the screen
        case .ended, .cancelled, .failed:
            firstFingerLocation = nil // Reset first finger location
            
            let minTravelDistance = view.frame.height // minimum travel distance of the card
            let minDragDistance = halfViewWidth // minimum dragging distance of the card
            let vector = CGPoint(x: velocity.x / 2, y: velocity.y / 2)
            let vectorDistance = hypot(vector.x, vector.y)
            
            let distanceDelta = minTravelDistance / panDistance
            let minimumDelta = CGPoint(x: offset.x * distanceDelta,
                                     y: offset.y * distanceDelta)
            
            if currentCard?.data != nil &&
                vectorDistance >= minTravelDistance {
                // Card dismissing threshold A: Data is available and
                // the projected travel distance is greater than or equals minimum distance
                animateCard(card, deltaX: vector.x, deltaY: vector.y)
            }
            else if currentCard?.data != nil &&
                        vectorDistance < minTravelDistance &&
                            panDistance >= minDragDistance {
                // Card dismissing thrshold B: Data is available and
                // the projected travel distance is less than the minimum travel distance
                // but the distance of card being dragged is greater than distance threshold
                animateCard(card, deltaX: minimumDelta.x, deltaY: minimumDelta.y)
            }
            
            // Reset card's position and rotation state
            else {
                // Bouncing effect
                let bounceVector = CGPoint(x: -(offset.x) / 8, y: -(offset.y) / 8)
                card.centerXConstraint.constant = startingCenterX + bounceVector.x
                card.centerYConstraint.constant = startingCenterY + bounceVector.y
                
                UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
                    self.updateLayout()
                    card.transform = self.startingTransform
                    
                    // Reset the next card's transform
                    self.nextCard?.setSize(status: .standby)
                } completion: { _ in
                    card.centerXConstraint.constant = self.startingCenterX
                    card.centerYConstraint.constant = self.startingCenterY
                    
                    UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseIn) {
                        self.updateLayout()
                    } completion: { _ in
                        self.cardIsBeingPanned = false
                    }
                }
            }
        default:
            debugPrint("Error handling card panning detection.")
        }
    }
    
    @objc private func twoFingerPanHandler(sender: UIPanGestureRecognizer) {
        if let card = sender.view as? Card {
            switch sender.state {
            case .began:
                startingCenterX = card.centerXConstraint.constant
                startingCenterY = card.centerYConstraint.constant
            case .changed:
                // Get the touch position
                let translation = sender.translation(in: card)
                
                // Card move to where the user's finger position is
                let zoomRatio = card.frame.width / card.bounds.width
                card.centerXConstraint.constant = startingCenterX + translation.x * zoomRatio
                card.centerYConstraint.constant = startingCenterY + translation.y * zoomRatio
                updateLayout()
                
            case .ended, .cancelled, .failed:
                // Move card back to original position
                card.centerXConstraint.constant = startingCenterX
                card.centerYConstraint.constant = startingCenterY
                UIView.animate(withDuration: 0.35, animations: {
                    self.updateLayout()
                })
            default:
                debugPrint("Error handling image panning")
            }
        }
    }
    
    @objc private func zoomHandler(sender: UIPinchGestureRecognizer) {
        if let card = sender.view as? Card {
            switch sender.state {
            case .began:
                startingTransform = card.transform
                
                // Hide navBar button
                if self.onboardCompleted {
                    self.collectionButton.tintColor = .clear
                }
                
                // Hide card's trivia overlay
                card.hideTriviaOverlay()
                
            case .changed:
                // Coordinate of the pinch center where the view's center is (0, 0)
                let pinchCenter = CGPoint(
                    x: sender.location(in: card).x - card.bounds.midX,
                    y: sender.location(in: card).y - card.bounds.midY)
                
                // Card transform behavior
                
                // Move the card to the opposite point of the pinch center if the scale delta > 1, vice versa
                let transform = card.transform.translatedBy(
                    x: pinchCenter.x, y: pinchCenter.y)
                    .scaledBy(x: sender.scale, y: sender.scale)
                    .translatedBy(x: -pinchCenter.x, y: -pinchCenter.y)
                
                // Limit the scale at which a card can be zoom in/out
                let newWidth = sender.scale * card.frame.width
                let minWidth = card.bounds.width
                let maxWidth = minWidth * K.ImageView.maximumScaleFactor
                if newWidth > minWidth && newWidth < maxWidth {
                    card.transform = startingTransform.concatenating(transform)
                }
                sender.scale = 1
                
                // Increase opacity of the overlay view as the card is enlarged
                let originalWidth = card.bounds.width
                let currentWidth = card.frame.width
                let maxOpacity: CGFloat = 0.6 // max opacity of the overlay view
                let cardWidthDelta = (currentWidth / originalWidth) - 1 // Percentage change of width
                let deltaToMaxOpacity: CGFloat = 0.2 // number of width delta to get maximum opacity
                    
                zoomOverlay.alpha = maxOpacity * min((cardWidthDelta / deltaToMaxOpacity), 1.0)
            
            case .ended, .cancelled, .failed:
                // Reset card's size
                UIView.animate(withDuration: 0.35, animations: {
                    card.transform = self.startingTransform
                    self.zoomOverlay.alpha = 0
                }) { _ in
                    if self.onboardCompleted {
                        self.collectionButton.tintColor = K.Color.tintColor
                    }
                }
                
                // Re-show trivia overlay if showOverlay is true
                if showOverlay == true {
                    card.showTriviaOverlay()
                }
            default:
                debugPrint("Error handling image zooming")
            }
        }
    }
    
    /// Show / Hidden every card's overlay view every time the current card is tapped onto.
    /// - Parameter sender: The tap gesture recognizer attached to the card.
    @objc private func tapHandler(sender: UITapGestureRecognizer) {
        switch sender.state {
        case .ended:
            for card in cardArray {
                // The method `toggleOverlay` in Card.swift toggles every card's visibility
                // and the global variable `showOverlay` in this class.
                card.toggleOverlay()
            }
        default:
            debugPrint("Error handling tap gesture.")
        }
    }
    
    private func attachGestureRecognizers(to card: Card) {
        card.addGestureRecognizer(panGestureRecognizer)
        card.addGestureRecognizer(pinchGestureRecognizer)
        card.addGestureRecognizer(twoFingerPanGestureRecognizer)
        card.addGestureRecognizer(tapGestureRecognizer)
    }
    
    private func removeGestureRecognizers(from card: Card) {
        card.removeGestureRecognizer(panGestureRecognizer)
        card.removeGestureRecognizer(pinchGestureRecognizer)
        card.removeGestureRecognizer(twoFingerPanGestureRecognizer)
        card.removeGestureRecognizer(tapGestureRecognizer)
    }
    
    //MARK: - Animation Methods
    
    private func animateCard(_ card: Card, deltaX: CGFloat, deltaY: CGFloat) {
        updateCardConstraints(card: card, deltaX: deltaX, deltaY: deltaY)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.updateLayout()
            self.resetNextCardTransform()
        } completion: { _ in
            card.removeFromSuperview()
            self.cardIsBeingPanned = false
            self.cardIndex += 1
            
            if self.currentCard?.data != nil {
                self.attachGestureRecognizers(to: self.currentCard!)
            }
            
            if self.nextCard != nil {
                self.addCardToView(self.nextCard!, atBottom: true)
            }
            
            if self.cardIndex > self.maxCardIndex {
                self.fetchNewData(initialRequest: false)
            }
            
            // Toggle the status of onboard completion
            if !self.onboardCompleted && self.cardIndex >= self.onboardData.count {
                self.onboardCompleted = true
                self.collectionButton.isEnabled = true
            }
            
            // Update the number of cards viewed by the user
            if self.onboardCompleted && self.cardIndex > self.maxCardIndex {
                self.viewCount += 1
            }
            
            DispatchQueue.main.async {
                self.refreshButtonState()
            }
            
            self.removeOldCacheData()
            
            // Request banner ad if conditions are met
            if self.onboardCompleted && !self.adReceived && self.viewCount > K.Banner.adLoadingThreshold {
                self.requestBannerAd()
            }
        }
    }
    
    /// Reset the next card's transform with animation
    private func resetNextCardTransform() {
        nextCard?.transform = .identity
    }
    
    private func updateCardConstraints(card: Card, deltaX: CGFloat, deltaY: CGFloat) {
        card.centerXConstraint.constant += deltaX
        card.centerYConstraint.constant += deltaY
    }
    
    private func updateLayout() {
        self.view.layoutIfNeeded()
    }
    
    // Maintain the maximum number of cache data
    private func removeOldCacheData() {
        let maxUndoNumber = K.Data.undoCardNumber
        let oldCardIndex = cardIndex - (maxUndoNumber + 1)
        if oldCardIndex >= 0 && oldCardIndex < cardArray.count {
            let oldCard = cardArray[oldCardIndex]
            oldCard.clearCache()
        }
    }
    
    //MARK: - Error Handling Section
    
    /// Present error message to the user if any error occurs in the data fetching process
    func networkErrorDidOccur() {
        // Make sure there's no existing alert controller being presented already.
        guard self.presentedViewController == nil else { return }
        
        hapticManager.prepareNotificationGenerator()
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: Z.AlertMessage.NetworkError.alertTitle,
                message: Z.AlertMessage.NetworkError.alertMessage,
                preferredStyle: .alert)
            
            // Retry button which send network request to the network manager
            let retryAction = UIAlertAction(title: Z.AlertMessage.NetworkError.actionTitle, style: .default) { _ in
                let requestNumber = K.Data.cacheDataNumber - self.cardArray.count
                self.networkManager.performRequest(numberOfRequests: requestNumber)
            }
            
            // Add actions to alert controller
            alert.addAction(retryAction)
            self.present(alert, animated: true, completion: nil)
            self.hapticManager.notificationHaptic?.notificationOccurred(.error)
        }
    }
    
}

extension HomeVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Recognizing pinch gesture only after the failure of a pan gesture
        if gestureRecognizer == pinchGestureRecognizer && otherGestureRecognizer == panGestureRecognizer {
            return true
        }
        
        // Recognizing two-finger pan gesture only after the failure of single-finger pan gesture
        if gestureRecognizer == twoFingerPanGestureRecognizer && otherGestureRecognizer == panGestureRecognizer {
            return true
        }
        return false
    }
}

extension HomeVC: DatabaseManagerDelegate {
    /// Number of saved images has reached the limit.
    func savedImagesMaxReached() {
        // Show alert to the user
        let alert = UIAlertController(title: Z.AlertMessage.DatabaseError.alertTitle,
                                      message: Z.AlertMessage.DatabaseError.alertMessage,
                                      preferredStyle: .alert)
        let acknowledgeAction = UIAlertAction(title: Z.AlertMessage.DatabaseError.actionTitle,
                                              style: .cancel)
        alert.addAction(acknowledgeAction)
        
        present(alert, animated: true, completion: nil)
    }
}

extension HomeVC: GADBannerViewDelegate {
    /// An ad request successfully receive an ad.
    func adViewDidReceiveAd(_ bannerView: GADBannerView) {
        if !adReceived {
            addBannerToBannerSpace(adBannerView)
            updateBannerViewSize(bannerView: bannerView)
            
            adReceived = true
        }
        
        // Animate the appearence of the banner view
        bannerView.alpha = 0
        UIView.animate(withDuration: 1.0) {
            bannerView.alpha = 1
        }
    }
    
    /// Failed to receive ad with error.
    func adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError) {
        debugPrint("adView: didFailToReceiveAdWithError: \(error.localizedDescription)")
    }
}
