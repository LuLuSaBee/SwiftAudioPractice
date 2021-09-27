//
//  UISlider+Rx.swift
//  SwiftAudioPractice
//
//  Created by Louis SL Liu on 2021/9/27.
//

import Foundation
import RxSwift
import RxCocoa
import UIKit
import MediaPlayer

extension Reactive where Base: UISlider {
    public var value: Binder<CMTime> {
        return Binder(self.base) { control, value in
            control.setValue( Float(CMTimeGetSeconds(value)), animated: false)
        }
    }
}
