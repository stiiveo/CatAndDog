//
//  CatViewController.swift
//  CatAndDog
//
//  Created by Jason Ou Yang on 2020/7/21.
//  Copyright © 2020 Jason Ou Yang. All rights reserved.
//

import UIKit

class CatViewController: UIViewController, CatDataManagerDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    @IBOutlet weak var refreshButton: UIButton!

    var catDataManager = CatDataManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        catDataManager.delegate = self
        startFetchImage()
    }

    @IBAction func refreshBtnPressed(_ sender: UIButton) {
        startFetchImage()
    }
    
    private func startFetchImage() {
        refreshButton.isEnabled = false
        refreshButton.tintColor = UIColor.systemGray
        indicator.startAnimating()
        catDataManager.performRequest()
    }

    // update image and UI components
    func dataDidFetch() {
        let imageArray = catDataManager.catImages.imageArray
        DispatchQueue.main.async {
            // update image
            guard let firstDownloadedImage = imageArray.first else { print("Fail to get image"); return }
            self.imageView.image = firstDownloadedImage
            
            // update UI components
            self.indicator.stopAnimating()
            self.refreshButton.isEnabled = true
            self.refreshButton.tintColor = UIColor.systemBlue
        }
    }
    
}

