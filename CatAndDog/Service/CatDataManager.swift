//
//  CatDataManager.swift
//  CatAndDog
//
//  Created by Jason Ou Yang on 2020/7/21.
//  Copyright © 2020 Jason Ou Yang. All rights reserved.
//

import UIKit

protocol CatDataManagerDelegate {
    func dataDidFetch()
    func errorDidOccur()
}

class CatDataManager {
    
    let catUrl = "https://api.thecatapi.com/v1/images/search"
    var delegate: CatDataManagerDelegate?
    let catImages = CatImages()
    var imageIndex: Int = 0
    var isInitialImageSetUp: Bool = false
    
    func performRequest(imageDownloadNumber: Int) {
        
        for _ in 0..<imageDownloadNumber {
            let session = URLSession(configuration: .default)
            guard let url = URL(string: catUrl) else {
                print("Failed to convert catUrl to URL object")
                return
            }
            let task = session.dataTask(with: url) { (data, response, error) in
                if error != nil {
                    self.delegate?.errorDidOccur()
                    print("Error occured during data fetching process.")
                    return
                } else {
                    if let safeData = data {
                        let processedData = self.removeBrecketsInJSON(data: safeData)
                        self.parseJSON(data: processedData)
                    }
                }
            }
            task.resume()
        }
        
    }
    
    private func removeBrecketsInJSON(data: Data) -> Data {
        
        // convert Data to String
        let dataToString = String(data: data, encoding: .utf8)!
        
        // convert String to Array
        var stringToArray = Array(dataToString)
        
        // remove the first and last element ('[' & ']') of the array
        stringToArray.removeFirst()
        stringToArray.removeLast()
        
        // convert Array to String
        var arrayToString: String = ""
        for character in stringToArray {
            arrayToString.append(character)
        }
        
        // convert String to Data
        let stringToData = arrayToString.data(using: .utf8)!
        
        return stringToData
    }
    
    private func parseJSON(data: Data) {
        let jsonDecoder = JSONDecoder()
        do {
            let decodedData = try jsonDecoder.decode(CatData.self, from: data)
            downloadImage(url: decodedData.url)
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    private func downloadImage(url: String) {
        guard let url = URL(string: url) else { print("Failed to convert JSON's url to URL obj."); return }
        do {
            let imageData = try Data(contentsOf: url)
            guard let image = UIImage(data: imageData) else { print("Failed to convert imageData into UIImage obj."); return }
            
            // attach index number to each downloaded image
            attachIndexToImage(image)
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    private func attachIndexToImage(_ newImage: UIImage) {
        imageIndex += 1
        catImages.imageArray["Image\(imageIndex)"] = newImage
        
        if isInitialImageSetUp == false {
            // if first 2 images are ready
            if catImages.imageArray["Image1"] != nil && catImages.imageArray["Image2"] != nil {
                // inform the delegate the first 2 images are ready
                delegate?.dataDidFetch()
                isInitialImageSetUp = true
            }
        }
        
        
    }
}
