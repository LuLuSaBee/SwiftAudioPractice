//
//  ViewController.swift
//  SwiftAudioPractice
//
//  Created by Louis SL Liu on 2021/9/8.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    var songData: SongData!

    let player = AVPlayer()
    var playerItem: AVPlayerItem!
    var songIndex = 0
    var isPlaying = true
    private var playerItemContext = 0
    var secondsOfSong: Double!
    var timer: Timer!
    var timeInterval = 0.1

    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var sliderBar: UISlider!

    override func viewDidLoad() {
        super.viewDidLoad()
        playMusic()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                of: object,
                change: change,
                context: context)
            return
        }

        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }

            switch status {
            case .readyToPlay:
                sliderBar.maximumValue = Float(playerItem.duration.seconds)
                setTimer()
            default:
                return
            }
        }
    }

    func setTimer() {
        timer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(updateSliderBar), userInfo: nil, repeats: true)
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @objc func updateSliderBar() {
        sliderBar.setValue(Float(playerItem.currentTime().seconds), animated: false)
    }

    @IBAction func slide(_ slider: UISlider) {
        stopTimer()
        sliderBar.setValue(slider.value, animated: false)
        playerItem.seek(to: CMTime(seconds: Double(slider.value), preferredTimescale: 1000), completionHandler: seekFinished)
    }

    func seekFinished(isFinished: Bool) {
        if isFinished {
            setTimer()
        }
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
        stopTimer()
        playMusic()
    }

    @IBAction func nextButtonClick(_ sender: Any) {
        if songIndex == songData.songSources.count - 1 {
            songIndex = 0
        } else {
            songIndex += 1
        }
        stopTimer()
        playMusic()
    }

    func playMusic() {
        let currentSong = songData.songSources[songIndex]
        guard let url = URL(string: currentSong) else { return }
        playerItem = AVPlayerItem(url: url)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new], context: &playerItemContext)
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

