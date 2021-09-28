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
    private var timeInterval = 0.1
    private var audioSession = AVAudioSession.sharedInstance()
    private var nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    private var nowPlayingInfo = [String: Any]()
    private let disposeBag = DisposeBag()

    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var previousButton: UIButton!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var nextButton: UIButton!
    @IBOutlet var sliderBar: UISlider!

    override func viewDidLoad() {
        super.viewDidLoad()
        prepareMusic()
        setupRemoteControll()
        setupNotifications()

        subscribePlayerButtons()
        subscribePlayer()
        subscribeSliderBar()

        sliderBar.isContinuous = false
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

    private func perviousMusic() {
        songIndex = (songIndex - 1 + songData.songSources.count) % songData.songSources.count
        prepareMusic()
    }

    private func nextMusic() {
        songIndex = (songIndex + 1) % songData.songSources.count
        prepareMusic()
    }

    private func prepareMusic() {
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
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem.duration.seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Rx
    func subscribePlayItemStatus() {
        playerItem.rx.status.subscribe(onNext: { [setupPlaying] status in
            switch status {
            case .readyToPlay:
                setupPlaying()
            default:
                return
            }
        }).disposed(by: disposeBag)

        playerItem.rx.didPlayToEnd.subscribe(onNext: { [nextMusic] _ in nextMusic() }).disposed(by: disposeBag)
    }

    func setupPlaying() {
        player.play()
        sliderBar.setValue(0, animated: false)
        sliderBar.maximumValue = Float(playerItem.duration.seconds)

        setNowPlayingInfo()

        do {
            try audioSession.setActive(true)
        } catch {
            print("error")
        }
    }

    func subscribePlayer() {
        player.rx.timeControlStatus.subscribe(onNext: { [setupWhenPlayerTimeControlStatusChange] status in
            setupWhenPlayerTimeControlStatusChange(status)
        }).disposed(by: disposeBag)
        
        player.rx.periodicTimeObserver(interval: CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
            .map { Float(CMTimeGetSeconds($0)) }
            .bind(to: sliderBar.rx.value)
            .disposed(by: disposeBag)
    }

    func setupWhenPlayerTimeControlStatusChange(status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1
        case .paused:
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
        default:
            return
        }

        setNowPlayingInfo()
    }

    func subscribePlayerButtons() {
        playButton.rx.tap.subscribe(onNext: { [player] _ in
            switch player.timeControlStatus {
            case .playing:
                player.pause()
            case .paused:
                player.play()
            default:
                return
            }
        }).disposed(by: disposeBag)

        previousButton.rx.tap.subscribe(onNext: { [perviousMusic] _ in perviousMusic() }).disposed(by: disposeBag)
        nextButton.rx.tap.subscribe(onNext: { [nextMusic] _ in nextMusic() }).disposed(by: disposeBag)
    }

    func setupNotifications() {
        NotificationCenter.default.rx
            .notification(AVAudioSession.interruptionNotification)
            .subscribe(onNext: { [handleInterruption] notification in
            handleInterruption(notification)
        })
            .disposed(by: disposeBag)
    }

    func handleInterruption(_ notification: Notification) {
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

    func subscribeSliderBar() {
        sliderBar.rx.value
            .subscribe(onNext: { [player, setNowPlayingInfo] value in
            player.seek(to: CMTime(seconds: Double(value), preferredTimescale: CMTimeScale(NSEC_PER_SEC)), completionHandler: { _ in setNowPlayingInfo() })
        }).disposed(by: disposeBag)
    }
}

