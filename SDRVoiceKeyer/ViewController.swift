//
//  ViewController.swift
//  SDRVoiceKeyer
//
//  Created by Peter Bourget on 2/10/17.
//  Copyright © 2017 Peter Bourget. All rights reserved.
//

import Cocoa

// http://stackoverflow.com/questions/29418310/set-color-of-nsbutton-programmatically-swift
extension NSImage {
    class func swatchWithColor(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.drawSwatch(in: NSMakeRect(0, 0, size.width, size.height))
        image.unlockFocus()
        return image
    }
}

class ViewController: NSViewController {
    
    
   
    var radioManager: RadioManager!
    
   

    // generated code
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(self.discoveredRadios), name: NSNotification.Name.init(rawValue: "K6TURadioFactory"), object: nil)
        
        // Do any additional setup after loading the view.
        do {
            try radioManager = RadioManager()
        }
        catch let error as NSError {
            // debug.print
            print("Error: \(error.userInfo.description)")
        }
        
       
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    // cleanup network sockets
    override func viewWillDisappear() {
        radioManager.radioFactory.close()
    }
    
    // my code
    
    // Notification handler - this will fire when the first radio is discovered and
    // anytime a new radio is discovered, or an existing radio has a major change
    // TODO: Need to account for multiple entries into this function
    func discoveredRadios(notification: NSNotification){
        
        if let info = notification.userInfo as? Dictionary<String,String> {
            // Check if value present before using it
            if let s = info["Error"] {
                serialNumberLabel.stringValue = s
                //print ("Error: " + s)
                return
            }
        }
        
        if radioManager != nil {
            do {
                serialNumberLabel.stringValue = try "S/N " + radioManager.DiscoverRadio()
                // enable buttons
                for case let button as NSButton in buttonStackView.subviews {
                    button.isEnabled = true
                }
            }
            catch let error as NSError {
                // debug.print
                print("Error: \(error.domain)")
            }
        } else {
            serialNumberLabel.stringValue = "Unable to find radio"
        }

        
        
        
    }

    // actions
    
    // button width = 46
    // button height = 32
    // var aaa = myButton.frame.size.width
    // var bbb = myButton.frame.size.height
    @IBAction func voiceButtonClicked(_ sender: NSButton) {
        
        
        //sender.image = NSImage.swatchWithColor ( color: NSColor.green, size: NSMakeSize (46, 32) )
//        for case let button as NSButton in self.view.subviews {
//            button.image = NSImage.swatchWithColor ( color: NSColor.green, size: NSMakeSize(100, 100) )
//
//        }
        
    }
    
//    func getSocket () {
//       var udpSocket: GCDAsyncUdpSocket
//        
//        udpSocket = GCDAsyncUdpSocket()
//        
//        udpSocket.didRe
//        
//        
//        
//    }
    

    // outlets
    
    @IBOutlet weak var voiceButton1: NSButton!
    
    @IBOutlet weak var serialNumberLabel: NSTextField!
    
    @IBOutlet weak var buttonStackView: NSStackView!
    
} // end class

