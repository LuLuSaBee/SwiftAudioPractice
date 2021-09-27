//
//  ViewController.swift
//  SwiftAudioPractice
//
//  Created by Louis SL Liu on 2021/9/8.
//

import UIKit
import AVFoundation
import MediaPlayer
import RxSwift
import RxCocoa
import RxRelay
import RxAVFoundation

class ViewController: UIViewController {
    var songData: SongData!

    private let player = AVPlayer()
    private var playerItem: AVPlayerItem!
    private var songIndex = 0
    private var playerItemContext = 0
    private var timer: Timer!
    private var timeInterval = 0.1
    private var audioSession = AVAudioSession.sharedInstance()
    private var nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    private var nowPlayingInfo = [String: Any]()
    private let disposeBag = DisposeBag()

    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var sliderBar: UISlider!

    override func viewDidLoad() {
        super.viewDidLoad()
        prepareMusic()
        setupRemoteControll()
        setupNotifications()
        
        subscribePlayerTimeControlStatus()
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

    @objc func playerDidFinishPlaying() {
        nextMusic()
    }

    private func setupRemoteControll() {
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

    private func setTimer() {
        timer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(updateSliderBar), userInfo: nil, repeats: true)
    }

    private func stopTimer() {
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
        setNowPlayingInfo()
    }

    private func seekFinished(isFinished: Bool) {
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

    private func perviousMusic() {
        if songIndex == 0 {
            songIndex = songData.songSources.count - 1
        } else {
            songIndex -= 1
        }
        prepareMusic()
    }

    private func nextMusic() {
        if songIndex == songData.songSources.count - 1 {
            songIndex = 0
        } else {
            songIndex += 1
        }
        prepareMusic()
    }

    private func prepareMusic() {
        stopTimer()

        let currentSong = songData.songSources[songIndex]
        guard let url = URL(string: currentSong) else { return }
        playerItem = AVPlayerItem(url: url)
        subscribePlayItemStatus()
        player.replaceCurrentItem(with: playerItem)

        nameLabel.text = url.lastPathComponent

        nowPlayingInfo[MPMediaItemPropertyTitle] = url.lastPathComponent
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "InternetAlbum"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Internet"
        setNowPlayingInfo()
    }

    func setNowPlayingInfo() {
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    // - MARK: Rx
    func subscribePlayItemStatus() {
        playerItem.rx.status.subscribe(onNext: { status in
            switch status {
            case .readyToPlay:
                self.setupPlaying()
            default:
                return
            }
        }).disposed(by: disposeBag)
    }

    func setupPlaying() {
        player.play()
        sliderBar.setValue(0, animated: false)
        sliderBar.maximumValue = Float(playerItem.duration.seconds)

        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem.duration.seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
        setNowPlayingInfo()

        setTimer()

        do {
            try audioSession.setActive(true)
        } catch {
            print("error")
        }
    }

    func subscribePlayerTimeControlStatus() {
        player.rx.timeControlStatus.subscribe(onNext: { status in
            switch status {
            case .playing:
                self.playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1
            case .paused:
                self.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
            default:
                return
            }

            self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.playerItem.currentTime().seconds
            self.setNowPlayingInfo()
        }).disposed(by: disposeBag)
    }
}

