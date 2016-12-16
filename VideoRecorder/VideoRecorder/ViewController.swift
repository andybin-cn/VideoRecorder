//
//  ViewController.swift
//  VideoRecorder
//
//  Created by Leo on 2016/12/16.
//  Copyright © 2016年 Binea. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    
    let recoder = STRecoder()
    var timer: Timer?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        recoder.previewView = self.view
        recoder.prepareToRecord()
        
        recoder.startRecord()
        
        if #available(iOS 10.0, *) {
            timer = Timer.init(timeInterval: 3000, repeats: false) { [weak self] (timer) in
                self?.recoder.stopRecord {
                    print("outputUrl: \(self?.recoder)")
                }
                timer.invalidate()
            }
        } else {
            // Fallback on earlier versions
        }
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

