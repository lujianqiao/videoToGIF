//
//  ViewController.swift
//  VideoToGIF
//
//  Created by lujianqiao on 2019/3/26.
//  Copyright © 2019 NGY. All rights reserved.
//

//UIColor
extension UIColor {
    
    //十六进制颜色
    class func kRGBColorFromHex(rgbValue: Int) -> (UIColor) {
        
        return UIColor(red: ((CGFloat)((rgbValue & 0xFF0000) >> 16)) / 255.0,
                       green: ((CGFloat)((rgbValue & 0xFF00) >> 8)) / 255.0,
                       blue: ((CGFloat)(rgbValue & 0xFF)) / 255.0,
                       alpha: 1.0)
    }
    
}

import UIKit
import SnapKit
import MobileCoreServices
import Photos
import PKHUD
import ImagePicker

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        // Do any additional setup after loading the view, typically from a nib.
    }

    func setUI() {
        
        let titlel = UILabel()
        titlel.text = "制作GIF"
        titlel.textColor = UIColor.kRGBColorFromHex(rgbValue: 0x303030)
        titlel.font = UIFont(name: "PingFangSC-Semibold", size: 27)
        view.addSubview(titlel)
        titlel.snp.makeConstraints { (make) in
            make.top.equalTo(100)
            make.centerX.equalToSuperview()
        }
        
        let takeVideoBtn = UIButton()
        takeVideoBtn.backgroundColor = UIColor.kRGBColorFromHex(rgbValue: 0xEDB783)
        takeVideoBtn.setTitle("录制视频转GIF", for: .normal)
        takeVideoBtn.clipsToBounds = true
        takeVideoBtn.layer.cornerRadius = 5
        takeVideoBtn.addTarget(self, action: #selector(takeVideoBtnAction), for: .touchUpInside)
        view.addSubview(takeVideoBtn)
        takeVideoBtn.snp.makeConstraints { (make) in
            make.top.equalTo(titlel.snp.bottom).offset(130)
            make.centerX.equalToSuperview()
            make.width.equalTo(150)
            make.height.equalTo(40)
        }
        
        
        let videoLibraryBtn = UIButton()
        videoLibraryBtn.backgroundColor = UIColor.kRGBColorFromHex(rgbValue: 0xEDB783)
        videoLibraryBtn.setTitle("本地视频转GIF", for: .normal)
        videoLibraryBtn.clipsToBounds = true
        videoLibraryBtn.layer.cornerRadius = 5
        videoLibraryBtn.addTarget(self, action: #selector(videoLibraryBtnAction), for: .touchUpInside)
        view.addSubview(videoLibraryBtn)
        videoLibraryBtn.snp.makeConstraints { (make) in
            make.top.equalTo(takeVideoBtn.snp.bottom).offset(30)
            make.centerX.equalToSuperview()
            make.width.equalTo(150)
            make.height.equalTo(40)
        }
        
        let imageLibraryBtn = UIButton()
        imageLibraryBtn.backgroundColor = UIColor.kRGBColorFromHex(rgbValue: 0xEDB783)
        imageLibraryBtn.setTitle("本地图片转GIF", for: .normal)
        imageLibraryBtn.clipsToBounds = true
        imageLibraryBtn.layer.cornerRadius = 5
        imageLibraryBtn.addTarget(self, action: #selector(imageLibraryBtnAction), for: .touchUpInside)
        view.addSubview(imageLibraryBtn)
        imageLibraryBtn.snp.makeConstraints { (make) in
            make.top.equalTo(videoLibraryBtn.snp.bottom).offset(30)
            make.centerX.equalToSuperview()
            make.width.equalTo(150)
            make.height.equalTo(40)
        }
    }
    
    //保存到相册
    func saveToTheAlbum(result: URL?)  {
        
        let gifData = NSData.init(contentsOfFile: result!.path)
        let library = PHPhotoLibrary.shared()
        let auth = PHPhotoLibrary.authorizationStatus()
        
        if auth == PHAuthorizationStatus.authorized{
            print("auth : \(auth)")
            //save data
            library.performChanges({
                let options = PHAssetResourceCreationOptions()
                PHAssetCreationRequest.forAsset().addResource(with: PHAssetResourceType.photo, data: gifData! as Data, options: options)
            }, completionHandler: { (success, error) in
                print("success : \(success)")
                
                DispatchQueue.main.async {
                    HUD.flash(.labeledSuccess(title: "GIF已保存至系统相册", subtitle: nil), delay:2.0)
                }
            })
        }else{
            PHPhotoLibrary.requestAuthorization({ (status) in
                print("status : \(status)")
                
            })
        }
        
        
    }
}

extension ViewController {
    
    //拍摄视频
    @objc func takeVideoBtnAction() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePicker = UIImagePickerController()
            UINavigationBar.appearance().tintColor = UIColor(red: 51.0/255.0, green: 51.0/255.0, blue: 51.0/255.0, alpha: 1.0)
            imagePicker.delegate = self
            imagePicker.sourceType = .camera
            imagePicker.mediaTypes = [kUTTypeMovie as String]
            imagePicker.allowsEditing = true
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    //选择视频
    @objc func videoLibraryBtnAction() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let imagePicker = UIImagePickerController()
            UINavigationBar.appearance().tintColor = UIColor(red: 51.0/255.0, green: 51.0/255.0, blue: 51.0/255.0, alpha: 1.0)
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.mediaTypes = [kUTTypeMovie as String]
            imagePicker.allowsEditing = true
            self.present(imagePicker, animated: true, completion: nil)
            
        }
    }
    //选择图片
    @objc func imageLibraryBtnAction() {
        
        let imagePickerController = ImagePickerController()
        imagePickerController.delegate = self
        present(imagePickerController, animated: true, completion: nil)
    }
    
    
    
    func makeGIFWithSource(path: String) {
        
        
        DispatchQueue.main.async {
            HUD.flash(.progress)
        }
        
        let frameCount = 10  //每秒取多少帧图片
        let delayTime  = Float(0.2)
        let urlPath = URL(fileURLWithPath: path)
        GIFMaker.creatGIFFormSource(fileURL: urlPath, frameCount: frameCount, delatTime: delayTime) { (result) in
            
            saveToTheAlbum(result: result)
            
        }
        
    }
    
}

//MARK: - IMAGE PICKER CONTROLLER DELEGATE
extension ViewController: UIImagePickerControllerDelegate {
    
    //MARK: Delegates
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let chosenVideo = info[UIImagePickerController.InfoKey.mediaType] as! CFString
        
        // Handle a movie capture
        if (CFStringCompare (chosenVideo, kUTTypeMovie, CFStringCompareFlags(rawValue: 0)) == CFComparisonResult.compareEqualTo)
        {
            self.dismiss(animated: true, completion: nil)
            let moviePath = (info[UIImagePickerController.InfoKey.mediaURL] as! NSURL).path
            
            
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(moviePath!))
            {
                print("compatible")
                print("movie Path : \(String(describing: (info[UIImagePickerController.InfoKey.mediaURL] as! NSURL).path))")
                makeGIFWithSource(path: moviePath!)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil) //5
        
    }
    
}

extension ViewController : ImagePickerDelegate {
    // MARK: - ImagePickerDelegate
    
    func cancelButtonDidPress(_ imagePicker: ImagePickerController) {
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    func wrapperDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
        guard images.count > 0 else { return }
        
    }
    
    func doneButtonDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
        
        imagePicker.dismiss(animated: true, completion: nil)
        
        if images.count > 0 {
            GIFMaker.creatGIFFormImages(images: images) { (result) in
                
                saveToTheAlbum(result: result)
                
            }
        }
    }
}

extension ViewController: UINavigationControllerDelegate {
    
}



