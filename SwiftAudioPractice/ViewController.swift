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
    @IBOutlet var playButton: UIButton!

    var songData: SongData!

    let player = AVPlayer()
    var playerItem: AVPlayerItem!
    var songIndex = 0
    var isPlaying = true

    override func viewDidLoad() {
        super.viewDidLoad()
        playMusic()
    }

    @IBAction func playButtonClick(_ sender: Any) {
        isPlaying = !isPlaying
        changePlayingInfo()
    }

    @IBAction func perviousButtonClick(_ sender: Any) {
        if songIndex == 0 {
            songIndex = songData.songSources.count - 1
        } else {
            songIndex -= 1
        }
        playMusic()
    }

    @IBAction func nextButtonClick(_ sender: Any) {
        if songIndex == songData.songSources.count - 1 {
            songIndex = 0
        } else {
            songIndex += 1
        }
        playMusic()
    }

    func playMusic() {
        let currentSong = songData.songSources[songIndex]
        guard let url = URL(string: currentSong) else { return }
        playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)

        nameLabel.text = url.lastPathComponent

        isPlaying = true
        changePlayingInfo()
    }

    func changePlayingInfo() {
        if isPlaying {
            player.play()
        } else {
            player.pause()
        }
        playButton.setImage(UIImage(systemName: isPlaying ? "pause.fill" : "play.fill"), for: .normal)
    }
}

