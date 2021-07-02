//
//  AlphaVideoView.swift
//  AlphaVideoiOSDemo
//
//  Created by lvpengwei on 2019/5/26.
//  Copyright © 2019 lvpengwei. All rights reserved.
//

import UIKit
import AVFoundation

public class AlphaVideoView: UIView {
    deinit {
        self.playerItem = nil
    }
    override public class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    var playerLayer: AVPlayerLayer { return layer as! AVPlayerLayer }
    private var player: AVPlayer? {
        get { return playerLayer.player }
    }
    var name: String = "" {
        didSet {
            loadVideo()
        }
    }
    public init(with name: String) {
        super.init(frame: .zero)
        commonInit()
        self.name = name
        loadVideo()
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    public func play() {
        player?.play()
    }
    public func pause() {
        player?.pause()
    }
    private func commonInit() {
        playerLayer.pixelBufferAttributes = [ (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA]
        playerLayer.player = AVPlayer()
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapAction)))
    }
    @objc private func tapAction() {
        guard let player = player else { return }
        guard player.rate == 0 else { return }
        player.play()
    }
    private var asset: AVAsset?
    private func loadVideo() {
        guard !name.isEmpty else {
            return
        }
        guard let videoURL = Bundle.main.url(forResource: name, withExtension: "mp4") else { return }
        self.asset = AVURLAsset(url: videoURL)
        self.asset?.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) { [weak self] in
            guard let self = self, let asset = self.asset else { return }
            DispatchQueue.main.async {
                self.playerItem = AVPlayerItem(asset: asset)
            }
        }
    }
    private var playerItem: AVPlayerItem? = nil {
        willSet {
            player?.pause()
        }
        didSet {
            player?.seek(to: CMTime.zero)
            setupPlayerItem()
            setupLooping()
            player?.replaceCurrentItem(with: playerItem)
        }
    }
    private var didPlayToEndTimeObsever: NSObjectProtocol? = nil {
        willSet(newObserver) {
            if let observer = didPlayToEndTimeObsever, didPlayToEndTimeObsever !== newObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    private func setupLooping() {
        guard let playerItem = self.playerItem, let player = self.player else {
            return
        }
        
        didPlayToEndTimeObsever = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: nil, using: { _ in
            player.seek(to: CMTime.zero) { _ in
                player.play()
            }
        })
    }
    private func setupPlayerItem() {
        guard let playerItem = playerItem else { return }
        let tracks = playerItem.asset.tracks
        guard tracks.count > 0 else {
            print("no tracks")
            return
        }
        //上下（上面是正常视频，下面是黑白视频）
        let videoSize = CGSize(width: tracks[0].naturalSize.width, height: tracks[0].naturalSize.height*0.5)
        //左右（右边是正常视频，左边是黑白视频）
        //let videoSize = CGSize(width: tracks[0].naturalSize.width * 0.5, height: tracks[0].naturalSize.height)
        guard videoSize.width > 0 && videoSize.height > 0 else {
            print("video size is zero")
            return
        }
        let composition = AVMutableVideoComposition(asset: playerItem.asset, applyingCIFiltersWithHandler: { request in
            //上下
            let sourceRect = CGRect(origin: .zero, size: videoSize)
            let alphaRect = sourceRect.offsetBy(dx: 0, dy: sourceRect.height)
            let filter = AlphaFrameFilter()
            filter.maskImage = request.sourceImage.cropped(to: sourceRect)
            filter.inputImage = request.sourceImage.cropped(to: alphaRect)
                .transformed(by: CGAffineTransform(translationX: 0, y: -alphaRect.height))
            return request.finish(with: filter.outputImage!, context: nil)
            //左右
//            let sourceRect = CGRect(origin: CGPoint(x: videoSize.width, y: 0), size: videoSize)
//            let alphaRect = CGRect(origin: .zero, size: videoSize)
//            let filter = AlphaFrameFilter()
//            filter.maskImage = request.sourceImage.cropped(to: alphaRect)
//            filter.inputImage = request.sourceImage.cropped(to: sourceRect).transformed(by: CGAffineTransform(translationX: -alphaRect.width, y: 0))
//            return request.finish(with: filter.outputImage!, context: nil)
        })
        
        composition.renderSize = videoSize
        playerItem.videoComposition = composition
        playerItem.seekingWaitsForVideoCompositionRendering = true
    }
}
