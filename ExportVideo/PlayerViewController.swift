//
//  PlayerViewController.swift
//  ExportVideo
//
//  Created by Ayushi on 09/06/21.
//

import UIKit
import AVKit
import Photos

final class PlayerViewController: UIViewController {
    @IBOutlet weak var playerView: UIView!

    private let videoUrl: URL
    private var player: AVPlayer!
    private var playerLayer: AVPlayerLayer!
    
    
    init(url: URL) {
        self.videoUrl = url
        super.init(nibName: String(describing: PlayerViewController.self), bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        player = AVPlayer(url: videoUrl)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = playerView.bounds
        playerView.layer.addSublayer(playerLayer)
        player.play()
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: nil) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    
    @IBAction func saveTapped(_ sender: Any) {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            switch status {
            case .authorized:
                self?.saveVideoToPhotos()
            default:
                let alert = UIAlertController(title: "Uh oh!",
                                              message: "Photos permission not granted", preferredStyle: .alert)
                let ok = UIAlertAction(title: "Okay", style: .default, handler: nil)
                alert.addAction(ok)
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func saveVideoToPhotos() {
      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.videoUrl)
      }) { [weak self] (isSaved, error) in
        if isSaved {
          print("Video saved.")
        } else {
          print("Cannot save video.")
          print(error ?? "unknown error")
        }
        DispatchQueue.main.async {
          self?.navigationController?.popViewController(animated: true)
        }
      }
    }
    
    deinit {
      NotificationCenter.default.removeObserver(
        self,
        name: .AVPlayerItemDidPlayToEndTime,
        object: nil)
    }
}
