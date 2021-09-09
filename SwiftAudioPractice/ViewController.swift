//
//  ViewController.swift
//  SwiftAudioPractice
//
//  Created by Louis SL Liu on 2021/9/8.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet var nameLabel: UILabel!

    var songSotre: SongStore!

    var player: AVPlayer!

    override func viewDidLoad() {
        super.viewDidLoad()
        let songURL = URL(string: "https://s3-us-west-2.amazonaws.com/s.cdpn.io/123941/Yodel_Sound_Effect.mp3")
        player = AVPlayer(url: songURL!)
    }

    @IBAction func playButtonClick(_ sender: Any) {
        playMusic()
    }

    func playMusic() {
        switch player.status {
        case .readyToPlay:
            print("readyToPlay")
        case .failed:
            print("failed")
        default:
            print("unkonw")
        }
        player.play()
    }
}

