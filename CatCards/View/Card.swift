//
//  Card.swift
//  CatCards
//
//  Created by Jason Ou Yang on 2020/11/2.
//  Copyright © 2020 Jason Ou Yang. All rights reserved.
//

import UIKit

class Card: UIView {

    var centerXConstraint: NSLayoutConstraint!
    var centerYConstraint: NSLayoutConstraint!
    var heightConstraint: NSLayoutConstraint!
    var widthConstraint: NSLayoutConstraint!
    var data: CatData?
    private let imageView = UIImageView()
    private let backgroundImageView = UIImageView()
    private var hintView = HintView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setCardViewStyle()
        addImageView()
        addBluredImageBackground()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setCardViewStyle() {
        // Card Style
        self.backgroundColor = K.Card.Style.backgroundColor
        self.layer.cornerRadius = K.Card.Style.cornerRadius
        
        // Card Shadow
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.5
        self.layer.shadowOffset = CGSize(width: 0.0, height: 0.5)
        self.layer.shadowRadius = 5
    }
    
    private func addImageView() {
        self.addSubview(imageView)
        imageView.frame = self.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Style
        imageView.isUserInteractionEnabled = true
        imageView.alpha = 0 // Default status
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = K.Card.Style.cornerRadius
    }
    
    /// Add duplicated imageView with blur effect behind the primary one as the background
    /// and fill the empty space in the cardView.
    private func addBluredImageBackground() {
        self.insertSubview(backgroundImageView, belowSubview: imageView)
        backgroundImageView.frame = imageView.frame
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.layer.cornerRadius = K.Card.Style.cornerRadius
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add blur effect onto it
        let blurEffect = UIBlurEffect(style: .systemChromeMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = backgroundImageView.frame
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        backgroundImageView.addSubview(blurEffectView)
    }
    
    func updateImage() {
        // Data is valid
        if data != nil {
            DispatchQueue.main.async {
                // Set imageView's image
                self.setImage(self.data!.image)
                
                UIView.animate(withDuration: 0.2) {
                    self.imageView.alpha = 1
                }
            }
        }
        // Data is NOT valid
        else {
            hintView.removeFromSuperview() // Remove hintView if there's any
            imageView.image = nil
            backgroundImageView.image = nil
            
            // Animate indicator and hide imageView
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.2) {
                    self.imageView.alpha = 0
                }
            }
        }
        
    }
    
    private func setImage(_ image: UIImage) {
        imageView.image = image
        backgroundImageView.image = self.imageView.image
        optimizeContentMode()
    }
    
    /// If the aspect ratio of the image and the imageView is close enough,
    /// set the imageView's content mode to 'scale aspect fill' mode to remove the margins around the image and
    /// improve the viewing experience
    func optimizeContentMode() {
        guard let image = imageView.image else { return }
        
        let imageRatio = image.size.width / image.size.height
        let imageViewRatio = imageView.bounds.width / imageView.bounds.height
        
        // Calculate the difference of the aspect ratio between the image and image view
        let ratioDifference = abs(imageRatio - imageViewRatio)
        let ratioThreshold = K.ImageView.dynamicScaleThreshold
        
        imageView.contentMode = (ratioDifference > ratioThreshold) ? .scaleAspectFit : .scaleAspectFill
    }
    
    func setAsTutorialCard(cardIndex index: Int) {
        if index == 1 {
            data = CatData(id: "zoomImage", image: K.Onboard.zoomImage)
        }
        
        DispatchQueue.main.async {
            self.addHintView(toCard: index)
        }
    }
    
    private func addHintView(toCard index: Int) {
        // Create an HintView instance and add it to Card
        hintView = HintView(frame: imageView.bounds)
        imageView.addSubview(hintView)
        hintView.addContentView(toCard: index)
    }
    
    func clearCache() {
        data = nil
        imageView.image = nil
        backgroundImageView.image = nil
    }
    
}

