//
//  ViewController.swift
//  VideoRecorder
//
//  Created by Leo on 2016/12/16.
//  Copyright © 2016年 Binea. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class ViewController: UIViewController {

    
    let recoder = STRecoder()
    var timer: Timer?
    var button: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        button = UIButton()
        button.setTitle("开始录制", for: UIControlState.normal)
        button.setTitle("停止录制", for: UIControlState.selected)
        button.addTarget(self, action: #selector(buttonTapped(sneder:)), for: UIControlEvents.touchUpInside)
        view.addSubview(button)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor).isActive = true
        button.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: -20).isActive = true
//        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
//        button.heightAnchor.constraint(equalToConstant: 200).isActive = true
        
        recoder.previewView = self.view
        recoder.prepareToRecord()
    }

    func buttonTapped(sneder: UIButton) {
        if sneder.isSelected {
            self.recoder.stopRecord {
                print("outputUrl: \(self.recoder.outputUrl)")
                let player = AVPlayerViewController(nibName: nil, bundle: nil)
                player.player = AVPlayer(url: self.recoder.outputUrl)
                self.present(player, animated: true, completion: nil)
            }
        } else {
            self.recoder.startRecord()
        }
        sneder.isSelected = !sneder.isSelected
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
}

