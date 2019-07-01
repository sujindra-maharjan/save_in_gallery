//
//  ImageSaver.swift
//  Runner
//
//  Created by Patryk on 13/06/2019.
//  Copyright © 2019 The Chromium Authors. All rights reserved.
//

import Foundation
import Photos

class ImageSaver: NSObject {
    // MARK: properties
    private var imagesRemaining: Int = 0
    private var savingMultipleImages: Bool = false
    private var onImagesSave: ((Bool) -> Void)?

    // MARK: constructors
    init(onImagesSave: ((Bool) -> Void)?) {
        self.onImagesSave = onImagesSave
    }
    
    // MARK: public interface
    func saveImage(_ image: UIImage, in dir: String?) {
        imagesRemaining = 1
        savingMultipleImages = false
        if let dir = dir {
            save(image, in: dir)
        }
        save(image)
    }

    func saveImages(_ images: [UIImage], in dir: String?) {
        imagesRemaining = images.count
        savingMultipleImages = true
        for image in images {
            if let dir = dir {
                save(image, in: dir)
            }
            save(image)
        }
    }

    func saveImages(_ images: [String: UIImage], in dir: String?) {
        savingMultipleImages = true
        imagesRemaining = images.count
        for (_, image) in images {
            if let dir = dir {
                save(image, in: dir)
            }
            save(image)
        }
    }
    
    // MARK: save in default album
    private func save(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(
            image,
            self,
            #selector(image(_: didFinishSavingWithError: contextInfo:)),
            nil
        )
    }
    
    // MARK: saving in custom named album
    private func save(_ image: UIImage, in dir: String) {
        if PHPhotoLibrary.authorizationStatus() != PHAuthorizationStatus.authorized {
            PHPhotoLibrary.requestAuthorization({ (status) -> Void in
                if PHPhotoLibrary.authorizationStatus() != PHAuthorizationStatus.authorized {
                    self.onSave(success: false)
                } else {
                    self.createAlbumIfNeeded(albumName: dir, completion: { assetCollection in
                        self.saveInCreatedAlbum(
                            image: image,
                            albumName: dir,
                            assetCollection: assetCollection
                        )
                    })
                }
            })
        } else {
            createAlbumIfNeeded(albumName: dir, completion: { assetCollection in
                self.saveInCreatedAlbum(
                    image: image,
                    albumName: dir,
                    assetCollection: assetCollection
                )
            })
        }
    }
    
    private func saveInCreatedAlbum(image: UIImage, albumName: String, assetCollection: PHAssetCollection) {
        PHPhotoLibrary.shared().performChanges({
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection)
            let enumeration: NSArray = assetPlaceHolder == nil ? [] : [assetPlaceHolder!]
            albumChangeRequest?.addAssets(enumeration)
        }, completionHandler: { (success, error) -> Void in
            self.onSave(success: (error == nil && success))
        })
    }
    
    func fetchAssetCollectionForAlbum(albumName: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        return collection.firstObject
    }
    
    func createAlbumIfNeeded(albumName: String, completion: @escaping (PHAssetCollection) -> Void) {
        if let assetCollection = self.fetchAssetCollectionForAlbum(albumName: albumName) {
            completion(assetCollection)
            return
        }
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
        }, completionHandler: { success, error in
            if success, let assetCollection = self.fetchAssetCollectionForAlbum(albumName: albumName) {
                completion(assetCollection)
            } else {
                self.onSave(success: false)
            }
        })
    }
    
    // MARK: on save handlers
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if error != nil {
            onSave(success: false)
            return
        }
        imagesRemaining -= 1
        if imagesRemaining == 0 {
            onSave(success: true)
        }
    }

    func onSave(success: Bool) {
        onImagesSave?(success)
        if !success {
            onImagesSave = nil
        }
    }
}
