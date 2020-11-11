//
//  CardView.swift
//  CatAndDog
//
//  Created by Jason Ou Yang on 2020/11/2.
//  Copyright © 2020 Jason Ou Yang. All rights reserved.
//

import UIKit

class CardView: UIView {

    internal let imageView = UIImageView()
    private let indicator = UIActivityIndicatorView()
    internal var data: CatData? {
        didSet {
            guard data != nil else {
                imageView.image = nil
                indicator.startAnimating()
                return
            }
            // value of data is not nil
            DispatchQueue.main.async {
                self.indicator.stopAnimating()
                self.set(image: self.data!.image)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(imageView)
        addImageViewConstraint()
        addIndicator()
        imageView.isUserInteractionEnabled = true
        indicator.startAnimating()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func set(image: UIImage) {
        setContentMode(image: image)
        imageView.image = image
    }
    
    private func setContentMode(image: UIImage) {
        let imageAspectRatio = image.size.width / image.size.height
        let imageViewAspectRatio = imageView.bounds.width / imageView.bounds.height
        // Determine the content mode by comparing the aspect ratio of the image and image view
        let aspectRatioDiff = abs(imageAspectRatio - imageViewAspectRatio)
        imageView.contentMode = (aspectRatioDiff >= K.ImageView.dynamicScaleThreshold) ? .scaleAspectFit : .scaleAspectFill
    }
    
    private func addImageViewConstraint() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: self.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        
        // Style
        imageView.layer.cornerRadius = K.CardView.Style.cornerRadius
        imageView.clipsToBounds = true
    }
    
    private func addIndicator() {
        self.addSubview(indicator)
        // constraint
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        indicator.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        // style
        indicator.style = .large
        indicator.hidesWhenStopped = true
    }
    
}
