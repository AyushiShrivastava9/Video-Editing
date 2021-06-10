//
//  ViewController.swift
//  ExportVideo
//
//  Created by Ayushi on 09/06/21.
//

import UIKit
import MobileCoreServices

class HomeViewController: UIViewController {
    private let editor = VideoEditor()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Export Video"
    }

    @IBAction func startRecording(_ sender: Any) {
        let pickerController = UIImagePickerController()
        pickerController.sourceType = .camera
        pickerController.mediaTypes = [kUTTypeMovie as String]
        pickerController.videoQuality = .typeIFrame1280x720
        pickerController.cameraDevice = .front
        pickerController.delegate = self
        present(pickerController, animated: true)
    }
    
    private func navigate(with url: URL) {
        DispatchQueue.main.async {
            let vc = PlayerViewController(url: url)
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
    }
}

extension HomeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard
            let url = info[.mediaURL] as? URL else {
            print("Cannot get video URL")
            return
        }
        
        dismiss(animated: true) {
            self.editor.export(fromVideoAt: url) { [weak self] exportedURL in
                guard let exportedURL = exportedURL else {
                    return
                }
                self?.navigate(with: exportedURL)
            }
        }
    }
}


