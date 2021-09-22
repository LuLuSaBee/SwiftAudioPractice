//
//  ViewController.swift
//  SwiftAudioPractice
//
//  Created by Louis SL Liu on 2021/9/8.
//

import UIKit
import AVFoundation
import MediaPlayer

class ViewController: UIViewController {
    var songData: SongData!

    let player = AVPlayer()
    var playerItem: AVPlayerItem!
    var songIndex = 0
    private var playerItemContext = 0
    var timer: Timer!
    var timeInterval = 0.1
    var audioSession = AVAudioSession.sharedInstance()
    var nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    var nowPlayingInfo = [String: Any]()

    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var sliderBar: UISlider!

    override func viewDidLoad() {
        super.viewDidLoad()
        prepareMusic()
        setupRemoteControll()
        setupNotifications()
    }

    func setupNotifications() {
        let notification = NotificationCenter.default
        notification.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        notification.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    @objc func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            player.pause()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                player.play()
            } else {
                return
            }
        default:
            return
        }
    }
    
    @objc func playerDidFinishPlaying(){
        nextMusic()
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
                player.play()
                sliderBar.maximumValue = Float(playerItem.duration.seconds)

                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem.duration.seconds
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
                nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo

                setTimer()

                do {
                    try audioSession.setActive(true)
                } catch {
                    print("error")
                }
            default:
                return
            }
        } else if keyPath == #keyPath(AVPlayer.timeControlStatus) {
            let status: AVPlayer.TimeControlStatus
            guard let statusNumber = change?[.newKey] as? NSNumber else {
                return
            }
            status = AVPlayer.TimeControlStatus(rawValue: statusNumber.intValue)!

            switch status {
            case .playing:
                playButtonPlaying()
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1
            case .paused:
                playButtonPaused()
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
            default:
                return
            }

            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
            nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
        }
    }

    func setupRemoteControll() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        MPRemoteCommandCenter.shared().playCommand.addTarget { event in
            self.player.play()
            return .success
        }
        MPRemoteCommandCenter.shared().pauseCommand.addTarget { event in
            self.player.pause()
            return .success
        }
        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { event in
            self.nextMusic()
            return .success
        }
        MPRemoteCommandCenter.shared().previousTrackCommand.addTarget { event in
            self.perviousMusic()
            return .success
        }
    }

    func playButtonPlaying() {
        playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
    }

    func playButtonPaused() {
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
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
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    func seekFinished(isFinished: Bool) {
        if isFinished {
            setTimer()
        }
    }

    @IBAction func playButtonClick(_ sender: Any) {
        switch player.timeControlStatus {
        case .playing:
            player.pause()
        case .paused:
            player.play()
        default:
            return
        }
    }

    @IBAction func perviousButtonClick(_ sender: Any) {
        perviousMusic()
    }

    @IBAction func nextButtonClick(_ sender: Any) {
        nextMusic()
    }

    func perviousMusic() {
        if songIndex == 0 {
            songIndex = songData.songSources.count - 1
        } else {
            songIndex -= 1
        }
        prepareMusic()
    }

    func nextMusic() {
        if songIndex == songData.songSources.count - 1 {
            songIndex = 0
        } else {
            songIndex += 1
        }
        prepareMusic()
    }

    func prepareMusic() {
        stopTimer()

        let currentSong = songData.songSources[songIndex]
        guard let url = URL(string: currentSong) else { return }
        playerItem = AVPlayerItem(url: url)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new], context: &playerItemContext)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: [.new], context: &playerItemContext)
        player.replaceCurrentItem(with: playerItem)

        nameLabel.text = url.lastPathComponent

        nowPlayingInfo[MPMediaItemPropertyTitle] = url.lastPathComponent
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "InternetAlbum"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Internet"
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
}

