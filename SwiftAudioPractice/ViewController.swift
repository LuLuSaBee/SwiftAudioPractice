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
    private var timeInterval = 0.1
    private var audioSession = AVAudioSession.sharedInstance()
    private var nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    private var nowPlayingInfo = [String: Any]()
    private var sliderMovedValue: Float? = nil
    private var playerItemBag = DisposeBag()
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
        
        do {
            try audioSession.setActive(true)
        } catch {
            print("error")
        }
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
        subscribePlayItem()
        player.replaceCurrentItem(with: playerItem)
        
        nameLabel.text = url.lastPathComponent
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = url.lastPathComponent
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "InternetAlbum"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Internet"
        setNowPlayingInfoAndCurrentTime()
    }
    
    private func setNowPlayingInfoAndCurrentTime() {
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    private func setSliderMovedValue(value: Float?) {
        sliderMovedValue = value
    }
    
    // MARK: - Rx
    private func subscribePlayItem() {
        playerItemBag = DisposeBag()
        
        let setupPlaying: () -> Void = { [player, sliderBar] in
            player.play()
            sliderBar?.setValue(0, animated: false)
        }
        
        playerItem.rx.status
            .subscribe(onNext: { [setupPlaying] status in
                switch status {
                case .readyToPlay:
                    setupPlaying()
                default:
                    return
                }
            })
            .disposed(by: playerItemBag)
        
        playerItem.rx.didPlayToEnd.subscribe(onNext: { [nextMusic] _ in nextMusic() }).disposed(by: playerItemBag)
        
        playerItem.rx.duration
            .map { $0.seconds }
            .filter { $0 > 0 }
            .subscribe(onNext: { [weak self, setNowPlayingInfoAndCurrentTime] seconds in
                self?.sliderBar.maximumValue = Float(seconds)
                
                self?.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = seconds
                setNowPlayingInfoAndCurrentTime()
            }).disposed(by: playerItemBag)
    }
    
    private func subscribePlayer() {
        let setupWhenPlayerTimeControlStatusChange: (AVPlayer.TimeControlStatus) -> Void = { [weak self, setNowPlayingInfoAndCurrentTime] status in
            switch status {
            case .playing:
                self?.playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                self?.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1
            case .paused:
                self?.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                self?.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
            default:
                return
            }
            setNowPlayingInfoAndCurrentTime()
        }
        
        player.rx.timeControlStatus
            .subscribe(onNext: { status in setupWhenPlayerTimeControlStatusChange(status) })
            .disposed(by: disposeBag)
        
        let compareSlideAndPlayerSeconds: (CMTime) -> Float =  { [weak self, setSliderMovedValue] value in
            let seconds = Float(CMTimeGetSeconds(value))
            
            if self?.sliderMovedValue == seconds {
                setSliderMovedValue(nil)
                return seconds
            }
            return self?.sliderMovedValue ?? seconds
        }
        
        player.rx.periodicTimeObserver(interval: CMTime(seconds: timeInterval, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
            .map { [compareSlideAndPlayerSeconds] value in return compareSlideAndPlayerSeconds(value) }
            .bind(to: sliderBar.rx.value)
            .disposed(by: disposeBag)
    }
    
    private func subscribePlayerButtons() {
        playButton.rx.tap
            .subscribe(onNext: { [player] _ in
                switch player.timeControlStatus {
                case .playing:
                    player.pause()
                case .paused:
                    player.play()
                default:
                    return
                }
            })
            .disposed(by: disposeBag)
        
        previousButton.rx.tap.subscribe(onNext: { [perviousMusic] _ in perviousMusic() }).disposed(by: disposeBag)
        nextButton.rx.tap.subscribe(onNext: { [nextMusic] _ in nextMusic() }).disposed(by: disposeBag)
    }
    
    private func setupNotifications() {
        let handleInterruption: (Notification) -> Void = {[player] notification in
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
        
        NotificationCenter.default.rx
            .notification(AVAudioSession.interruptionNotification)
            .subscribe(onNext: { [handleInterruption] notification in
                handleInterruption(notification)
            })
            .disposed(by: disposeBag)
    }
    
    private func subscribeSliderBar() {
        sliderBar.rx.controlEvent(.valueChanged)
            .subscribe(onNext: { [sliderBar, setSliderMovedValue] _ in
                setSliderMovedValue(sliderBar?.value)
            })
            .disposed(by: disposeBag)
        
        sliderBar.rx.controlEvent([.touchUpInside, .touchUpOutside])
            .subscribe(onNext: { [sliderBar, player, setNowPlayingInfoAndCurrentTime] _ in
                player.seek(to: CMTime(seconds: Double(sliderBar!.value), preferredTimescale: CMTimeScale(NSEC_PER_SEC)), completionHandler: { _ in setNowPlayingInfoAndCurrentTime() })
            })
            .disposed(by: disposeBag)
    }
}

