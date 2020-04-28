/**
 * Copyright (c) 2019 Peter Bourget W6OP
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/*
 MainViewController.swift
 SDRVoiceKeyer
 
 Created by Peter Bourget on 2/10/17.
 Copyright © 2019 Peter Bourget W6OP. All rights reserved.
 Description: Main View Controller for the SDR Voice Keyer
 */

import Cocoa
import Repeat

/*
 MainViewController.swift
 SDRVoiceKeyer
 
 Created by Peter Bourget on 2/10/17.
 Copyright © 2019 Peter Bourget W6OP. All rights reserved.
 Description: Main View Controller for the SDR Voice Keyer
 */
class ViewController: NSViewController, RadioManagerDelegate, PreferenceManagerDelegate, AudioManagerDelegate {
    
    var radioManager: RadioManager!
    var audiomanager: AudioManager!
    var preferenceManager: PreferenceManager!
    
    // this is only used in showPreferences
    var guiClientView = [(model: String, nickname: String, stationName: String, default: String, serialNumber: String, clientId: String, handle: UInt32)]()
    
  private var defaultStation = (model: "", nickname: "", stationName: "", default: "", serialNumber: "", clientId: "", handle: UInt32())
    
    // view of available slices for the view controller
    private var sliceView = [(sliceLetter: String, radioMode: RadioMode, txEnabled: Bool, frequency: String, sliceHandle: UInt32)]()
    
    private let radioKey = "defaultRadio"
    
    var isRadioConnected = false
    var isBoundToClient = false
    var boundClientId: String? = nil
    var connectedStationName = ""
    var connectedStationHandle: UInt32 = 0
    
    var timerState: String = "ON"
    var idTimer :Repeater?
    var idlabelTimer :Repeater?
    
    lazy var window: NSWindow! = self.view.window
    
    // MARK: Outlets ---------------------------------------------------------------------------
    @IBOutlet weak var voiceButton1: NSButton!
    @IBOutlet weak var serialNumberLabel: NSTextField!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var buttonStackView: NSStackView!
    @IBOutlet weak var buttonStackViewTwo: NSStackView!
    @IBOutlet weak var gainSlider: NSSlider!
    @IBOutlet weak var gainLabel: NSTextField!
    @IBOutlet weak var buttonSendID: NSButton!
    @IBOutlet weak var buttonStop: NSButton!
    @IBOutlet weak var labelSlice: NSTextField!
    @IBOutlet weak var labelMode: NSTextField!
    @IBOutlet weak var labelFrequency: NSTextField!
    @IBOutlet weak var labelStation: NSTextField!
    
    // MARK: Actions ---------------------------------------------------------------------------
    // this handles all of the voice buttons - use the tag value to determine which audio file to load
    @IBAction func voiceButtonClicked(_ sender: NSButton) {
        voiceButtonSelected(buttonNumber: sender.tag)
    }
    
    // show the preference pane
    @IBAction func buttonShowPreferences(_ sender: AnyObject) {
        showPreferences(sender)
    }
    
    // stop the current voice playback
    @IBAction func stopButtonClicked(_ sender: NSButton) {
        stopTransmitting()
    }
    
    @IBAction func sendID(_ sender: NSButton) {
        
        self.idlabelTimer = nil
        voiceButtonSelected(buttonNumber: sender.tag)
    }
    
    // update the label when the slider is changed
    @IBAction func gainSliderChanged(_ sender: NSSlider) {
        gainLabel.stringValue = "\(gainSlider.intValue)"
        self.updateUserDefaults()
    }
    
    @IBAction func updateFilePreferences(_ sender: AnyObject){
        showFilePreferences(sender)
    }
    
    // enable the id timer
    @IBAction func enableIDTimer(_ sender: NSButton) {
        
        // reset back for distribution
        let timerInterval: Int = Int(UserDefaults.standard.string(forKey: "TimerInterval") ?? "10") ?? 10
        
        switch sender.state {
        case .on:
            preferenceManager.enableTimer(isEnabled: true, interval: timerInterval )
        case .off:
            preferenceManager.enableTimer(isEnabled: false, interval: timerInterval )
        default: break
        }
    }
    // MARK: Generated Code ---------------------------------------------------------------------------
    // generated code
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create the preference manager
        preferenceManager = PreferenceManager()
        preferenceManager.preferenceManagerDelegate = self
        
        // create an instance of my radio manager and assign a delegate from it so I can handle events it raises
        radioManager = RadioManager()
        radioManager.radioManagerDelegate = self
        
        // create the audio manager
        audiomanager = AudioManager()
        audiomanager.audioManagerDelegate = self
        self.statusLabel.stringValue = "Connecting"
        
        updateButtonTitles(view: self.view)
        
        if let mutableAttributedTitle = buttonStop.attributedTitle.mutableCopy() as? NSMutableAttributedString {
            mutableAttributedTitle.addAttribute(.foregroundColor, value: NSColor.red, range: NSRange(location: 0, length: mutableAttributedTitle.length))
            buttonStop.attributedTitle = mutableAttributedTitle
        }
        
        disableVoiceButtons()
        
        // FOR DEBUG: delete user defaults
        //deleteUserDefaults()
        
        loadUserDefaults(isGuiClientUpdate: false)
    }
    
    // generated code
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    // don't allow full screen
    override func viewDidAppear() {
        window.styleMask.remove(.resizable)
        // keep on top of other windows
        self.window.level = NSWindow.Level.statusBar
    }
    // generated code
    override func viewWillDisappear() {
        
    }
    
    // MARK: GUIClients Message Handling ---------------------------------------------------------------------------
    
    /**
     receive messages from the audio manager
     - parameter key: AudioMessage - enum value for the message
     - parameter messageData: String - data to be added to the message
     */
    func audioMessageReceived(messageKey: AudioMessage, message: String) {
        var heading: String
        
        switch messageKey {
        case AudioMessage.FileMissing:
            heading = "Missing File"
        case AudioMessage.InvalidFileType:
            heading = "Invalid File Type"
        case AudioMessage.ButtonNotConfigured:
            heading = "Button Not Configured"
        case AudioMessage.Error:
            heading = "An Error Has Occurred"
        case AudioMessage.InvalidSampleRate:
            heading = "Invalid Sample Rate"
        }
        
        let alert = NSAlert()
        alert.messageText = heading
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: { (response) in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
        })
    }
    
    /**
     A new GUIClient has appeared on the network. We want to add it to our list
     in case the user wants to select a new radio/station.
     */
    func didAddGUIClients(discoveredGUIClients: [(model: String, nickname: String, stationName: String, default: String, serialNumber: String, clientId: String, handle: UInt32)], isGuiClientUpdate: Bool) {
        
        if guiClientView.filter({ $0.stationName == defaultStation.stationName }).isEmpty {
            guiClientView += discoveredGUIClients
        }
    }
    
    /**
     Load the information for the default radio if there is any.
     Check how many radios were discovered. If there is a default and it matches the discovered radio - connect
     otherwise show the preference pane. Also if there is a default, update its information
     if there are multiple radios, see if one is the default, if so - connect
     otherwise pop the preferences pane.
     This is the normal flow. When the Connect button is clicked it goes straight to doConnectToradio()
     */
    func didDiscoverGUIClients(discoveredGUIClients: [(model: String, nickname: String, stationName: String, default: String, serialNumber: String, clientId: String, handle: UInt32)], isGuiClientUpdate: Bool) {
        
        loadUserDefaults(isGuiClientUpdate: isGuiClientUpdate)
        
        if guiClientView.filter({ $0.stationName == defaultStation.stationName }).isEmpty {
            guiClientView += discoveredGUIClients
        } else {
            guiClientView.removeAll(where: { $0.stationName == defaultStation.stationName })
            guiClientView += discoveredGUIClients
        }
        
        // find if a default is set and connect if it is else show preference panel
        if let index = discoveredGUIClients.firstIndex(where: {$0.stationName == self.defaultStation.stationName}) {
            
            self.defaultStation.model = discoveredGUIClients[index].model
            self.defaultStation.nickname = discoveredGUIClients[index].nickname
            self.defaultStation.stationName = discoveredGUIClients[index].stationName
            
            if !isRadioConnected  {
                self.doConnectRadio(serialNumber: self.defaultStation.serialNumber,stationName: self.defaultStation.stationName, clientId: self.defaultStation.clientId,  doConnect: true)
            }
        } else {
            self.showPreferences("" as AnyObject)
        }
    }
    
    /**
     After the initial discovery we need to wait for updates to get the client id
     */
    func didUpdateGUIClients(discoveredGUIClients: [(model: String, nickname: String, stationName: String, default: String, serialNumber: String, clientId: String, handle: UInt32)], isGuiClientUpdate: Bool) {
        
        if guiClientView.filter({ $0.stationName == connectedStationName }).isEmpty {
            
            guiClientView += discoveredGUIClients
        }
        
        // this makes it version 3 only
        if let index = discoveredGUIClients.firstIndex(where: {$0.stationName == connectedStationName}) {
            
            if discoveredGUIClients[index].clientId != "" {
                defaultStation.clientId = discoveredGUIClients[index].clientId
                updateUserDefaults()
                
                if !isBoundToClient {
                    doBindToStation(clientId: discoveredGUIClients[index].clientId, station: discoveredGUIClients[index].stationName)
                }
            }
        }
    }
    
    /**
     A GUIClient has disappeared from the network so we will remove it from our collection.
     First get the handle so we can remove the slices too
     */
    func didRemoveGUIClients(station: String) {
        
        if !guiClientView.filter({ $0.stationName == station }).isEmpty {
            let handle = guiClientView.first( where: { $0.stationName == station })?.handle
            sliceView.removeAll( where: { $0.sliceHandle == handle})
        }
        
        guiClientView.removeAll(where: { $0.stationName == station})
        
        if (station == connectedStationName){
            connectedStationName = ""
            connectedStationHandle = 0
            isBoundToClient = false
            
            updateView(sliceHandle: 0)
        }
        
    }
    
    // MARK: Radio Methods ---------------------------------------------------------------------------
    /**
     Select the desired radio and instruct the RadioManager to start the connect process.
     - parameter serialNumber: String
     - parameter doConnect: Bool
     */
    func doConnectRadio(serialNumber: String, stationName: String, clientId: String, doConnect: Bool) {
        
        // if already connected we need to cleanup before connecting again
        if isRadioConnected {
            doBindToStation(clientId: clientId, station: stationName)
            return
        }
        
        if self.radioManager.connectToRadio(serialNumber: serialNumber, clientStation: stationName, clientId: clientId, doConnect: doConnect) == true {
            self.connectedStationName = stationName
            self.view.window?.title = "SDR Voice Keyer - " + self.defaultStation.nickname
            self.isRadioConnected = true
            self.statusLabel.stringValue = "Connected"
        }
    }
    
    /**
     Bind to the desired station with the client id.
     - parameter clientId: String
     */
    func doBindToStation(clientId: String, station: String)  {
        
        connectedStationHandle = self.radioManager.bindToStation(clientId: clientId, station: station)
        
        if connectedStationHandle != 0 {
            self.view.window?.title = "SDR Voice Keyer - " + self.defaultStation.nickname
            isBoundToClient = true
            connectedStationName = station
            
            updateView(sliceHandle: connectedStationHandle)
          
            if sliceView.firstIndex(where: { $0.txEnabled == true && $0.radioMode != RadioMode.other }) != nil {
                enableVoiceButtons(validSliceAvailable: true)
            }
        }
    }
    
    /**
     Request to be disconnected from the selected radio.
     */
    func didDisconnectFromRadio() {
        self.isRadioConnected = false
        self.isBoundToClient = false
        self.connectedStationName = ""
        self.connectedStationHandle = 0
        self.statusLabel.stringValue = "Disconnected"
    }
    
    /**
     Immediately stop transmitting
     */
    func stopTransmitting() {
        let xmitGain = gainSlider.intValue
        radioManager.keyRadio(doTransmit: false, xmitGain: Int(xmitGain))
        self.timerExpired = false
    }
    
    /**
     Update the status labels when the radio notifies us of a change
     */
    func updateView(sliceHandle: UInt32) {
        
        if sliceView.firstIndex(where: { $0.sliceHandle == connectedStationHandle && $0.txEnabled == true && $0.radioMode != RadioMode.other }) != nil {
            
            if let index = sliceView.firstIndex(where: { $0.sliceHandle == connectedStationHandle && $0.txEnabled == true && $0.radioMode != RadioMode.other }) {
               
                self.labelFrequency.stringValue = sliceView[index].frequency
                self.labelMode.stringValue = sliceView[index].radioMode.rawValue
                self.labelSlice.stringValue = "Slice \(sliceView[index].sliceLetter)"
                self.labelStation.stringValue = self.connectedStationName
            }
        } else {
            self.labelFrequency.stringValue = ""
            self.labelMode.stringValue = ""
            self.labelSlice.stringValue = "Slice ??"
            self.labelStation.stringValue = self.connectedStationName
        }
    }
    
    
    // MARK: Slice Message Handling ---------------------------------------------------------------------------
    
    /**
     Add a slice information object to the local sliceView collection.
     */
    func didAddSlice(slice: [(sliceLetter: String, radioMode: RadioMode, txEnabled: Bool, frequency: String, sliceHandle: UInt32)]) {
        
        self.sliceView += slice
        
        updateView(sliceHandle: slice[0].sliceHandle)
    }
    
    /**
     Find the slice to be updated by its handle.
     */
    func didUpdateSlice(sliceHandle: UInt32, sliceLetter: String, sliceStatus: SliceStatus, newValue: Any) {
        
        // find the slice to update
        if let index = sliceView.firstIndex(where: { $0.sliceHandle == sliceHandle &&  $0.sliceLetter == sliceLetter }) {
            
            switch sliceStatus {
                case .txEnabled:
                    sliceView[index].txEnabled = newValue as! Bool
                case .active:
                break // not used
                case .mode:
                    sliceView[index].radioMode = newValue as! RadioMode
                case .frequency:
                    sliceView[index].frequency = newValue as! String
            }
        }
        
        if sliceView.firstIndex(where: { $0.sliceHandle == connectedStationHandle && $0.txEnabled == true && $0.radioMode != RadioMode.other }) != nil {
            
            updateView(sliceHandle: sliceHandle)
            enableVoiceButtons(validSliceAvailable: true)
        } else {
            disableVoiceButtons()
        }
    }
    
    /**
     Remove a slice information object from the local sliceView collection.
     */
    func didRemoveSlice(sliceHandle: UInt32, sliceLetter: String) {
        
        if let index = sliceView.firstIndex(where: { $0.sliceHandle == sliceHandle && $0.sliceLetter == sliceLetter }) {
            sliceView.remove(at: index)
        }
        
        if sliceView.firstIndex(where: { $0.sliceHandle == connectedStationHandle && $0.txEnabled == true && $0.radioMode != RadioMode.other }) != nil {
            enableVoiceButtons(validSliceAvailable: true)
            updateView(sliceHandle: sliceHandle)
        } else {
            disableVoiceButtons()
            updateView(sliceHandle: 0)
        }
    }
    
    // MARK: Button Handling ---------------------------------------------------------------------------
    
    /**
     Handle button clicks etc. from any voice button
     - parameter buttonNumber: Int
     */
    func voiceButtonSelected(buttonNumber: Int) {
        
        var transmitGain: Int = 35
        
        self.timerExpired = false
        self.buttonSendID.wantsLayer = true
        self.buttonSendID.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        DispatchQueue.main.async {
            let xmitGain = self.gainSlider.intValue
            transmitGain = Int(xmitGain)
        }
        
        if self.isRadioConnected {
            selectAudioFile(buttonNumber: buttonNumber, transmitGain: transmitGain)
        } else {
            let alert = NSAlert()
            alert.messageText = "Radio Unavailable"
            alert.informativeText = "The Radio GUI seems to have gone away."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: { (response) in
                if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
            })
        }
    }
    
    /**
     Select the audio file to transmit and return it as an array
     of 32 bit floats
     - parameter buttonNumber: Int
     - parameter transmitGain: Int
     */
    func selectAudioFile(buttonNumber: Int, transmitGain: Int){
        var floatArray = [Float]()
        
        floatArray = self.audiomanager.selectAudioFile(buttonNumber: buttonNumber)
        
        if floatArray.count > 0 {
            self.radioManager.keyRadio(doTransmit: true, buffer: floatArray, xmitGain: transmitGain)
        }
    }
    
    /**
     Refresh the voice buttons.
     */
    func doUpdateButtons() {
        enableVoiceButtons(validSliceAvailable: true)
    }
    
    /**
     Refresh the voice buttons labels.
     */
    func doUpdateButtonLabels() {
        updateButtonTitles(view: self.view)
        audiomanager.clearFileCache()
        
        enableVoiceButtons(validSliceAvailable: true)
    }
    
    /**
     Enable all the voice buttons.
     */
    func enableVoiceButtons(validSliceAvailable: Bool){
        
        if sliceView.firstIndex(where: { $0.txEnabled == true && $0.radioMode != RadioMode.other }) != nil {
            
            if isBoundToClient  {
                for case let button as NSButton in self.buttonStackView.subviews {
                    if UserDefaults.standard.string(forKey: String(button.tag)) != "" {
                        button.isEnabled = self.isRadioConnected
                    } else {
                        button.isEnabled = false
                    }
                }
                
                for case let button as NSButton in self.buttonStackViewTwo.subviews {
                    if UserDefaults.standard.string(forKey: String(button.tag)) != "" {
                        button.isEnabled = self.isRadioConnected
                    } else {
                        button.isEnabled = false
                    }
                }
                
                // Send ID button if it has been configured
                if UserDefaults.standard.string(forKey: String(102)) != "" {
                    buttonSendID.isEnabled = self.isRadioConnected
                } else {
                    buttonSendID.isEnabled = false
                }
            }
        } else {
            disableVoiceButtons()
        }
    }
    
    /**
     Disable all the voice buttons.
     */
    func disableVoiceButtons(){
        
        for case let button as NSButton in self.buttonStackView.subviews {
            button.isEnabled = false
        }
        
        for case let button as NSButton in self.buttonStackViewTwo.subviews {
            button.isEnabled = false
        }
        
        buttonSendID.isEnabled = false
    }
    
    /**
     Collect all the buttons from view and subviews and update their label (title)
     - parameter view: - the view to search
     */
    func updateButtonTitles(view: NSView) {
        
        var results = [NSButton]()
        let offset = 10 // labels start with tag = 11
        
        for subview in view.subviews as [NSView] {
            if let button = subview as? NSButton {
                if button.tag != 0 && button.tag != 102 {
                    results += [button]
                    button.title = UserDefaults.standard.string(forKey: String(button.tag + offset)) ?? ""
                }
            } else {
                updateButtonTitles(view: subview)
            }
        }
    }
    
    // MARK: User Defaults ---------------------------------------------------------------------------
    
    // if defaults exists then retrieve them and update them
    // if one of the self.guiClients matches one of these set default to yes in self.guiClients
    func loadUserDefaults(isGuiClientUpdate: Bool) {
        
        if let defaults = UserDefaults.standard.dictionary(forKey: radioKey) {
            self.defaultStation.model = defaults["model"] as! String
            self.defaultStation.nickname = defaults["nickname"] as! String
            
            self.defaultStation.stationName = defaults["stationName"] as! String
            
            self.defaultStation.default = defaults["default"] as! String
            self.defaultStation.serialNumber = defaults["serialNumber"] as! String
            // only happens after connect
            if isGuiClientUpdate {
                //self.defaultStation.clientId = defaults["clientId"] as! String
            }
            
            if defaults["xmitGain"] != nil {
                self.gainSlider.intValue = Int32(defaults["xmitGain"] as! String) ?? 35
                self.gainLabel.stringValue = defaults["xmitGain"] as! String
            } else {
                self.gainSlider.intValue = 35
                self.gainLabel.stringValue = "35"
            }
            
            updateUserDefaults()
        }
    }
    /**
     Update the user defaults.
     */
    func updateUserDefaults() {
        
        var defaults = [String : String]()
        
        defaults["model"] = defaultStation.model
        defaults["nickname"] = defaultStation.nickname
        defaults["stationName"] = defaultStation.stationName
        defaults["default"] = defaultStation.default
        defaults["serialNumber"] = defaultStation.serialNumber
        //defaults["clientId"] = defaultStation.clientId
        defaults["xmitGain"] = "\(gainSlider.intValue)"
        
        UserDefaults.standard.set(defaults, forKey: radioKey)
        UserDefaults.standard.set(timerState, forKey: "TimerState")
    }
    
    /**
     Delete all the default settings. This is just used for debugging.
     */
    func deleteUserDefaults(){
        
        UserDefaults.standard.set(nil, forKey: radioKey)
        UserDefaults.standard.set(nil, forKey: "NSNavLastRootDirectory")
        UserDefaults.standard.set(nil, forKey: "TimerState")
        UserDefaults.standard.set(nil, forKey: "TimerInterval")
        
        for i in 0..<21 {
            UserDefaults.standard.set(nil, forKey: "\(i)")
        }
        
        UserDefaults.standard.set(nil, forKey: "\(101)")
        UserDefaults.standard.set(nil, forKey: "\(102)")
    }
    
    
    
    // MARK: Timer Methods ---------------------------------------------------------------------------
    
    /**
     Turn on or off the ID timer.
     */
    func doSetTimer(isEnabled: Bool, interval: Int) {
        self.idTimer = Repeater(interval: .minutes(interval), mode: .infinite) { _ in
            print("timer fired = \(interval)")
            //self.selectAudioFile(buttonNumber: 102, transmitGain: transmitGain)
            UI{
                //self.labelSendID.backgroundColor = NSColor.green
                //self.labelSendID.isHidden = false
                self.startLabelTimer()
            }
        }
        
        self.idTimer!.start()
    }
    var timerExpired = false
    func startLabelTimer() {
        
        self.idlabelTimer = Repeater(interval: .milliseconds(750), mode: .infinite) { _ in
            UI{
                if self.timerExpired {
                    self.timerExpired = false
                    //if self.labelSendID.isHidden {
                    //self.labelSendID.backgroundColor = NSColor.green
                    self.buttonSendID.wantsLayer = true
                    self.buttonSendID.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
                    //self.labelSendID.isHidden = false
                } else {
                    self.timerExpired = true
                    //self.labelSendID.isHidden = true
                    //self.labelSendID.backgroundColor = NSColor.red
                    self.buttonSendID.wantsLayer = true
                    self.buttonSendID.layer?.backgroundColor = NSColor.green.cgColor
                }
            }
        }
        
        self.idlabelTimer!.start()
    }
    
    // MARK: Preferences ---------------------------------------------------------------------------
    
    /**
     Show the file preferences panel and populate it
     */
    func showFilePreferences(_ sender: AnyObject) {
        let SB = NSStoryboard(name: "Main", bundle: nil)
        let PVC: FilePreferences = SB.instantiateController(withIdentifier: "filePreferences") as! FilePreferences
        PVC.preferenceManager = self.preferenceManager
        
        //presentViewControllerAsSheet(PVC)
        presentAsModalWindow(PVC)
        // present(_ PVC: NSViewController, asPopoverRelativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge, behavior: NSPopover.Behavior)
        
    }
    
    
    /**
     Show the radio selector panel and populate it
     */
    func showPreferences(_ sender: AnyObject) {
        let SB = NSStoryboard(name: "Main", bundle: nil)
        let PVC: RadioPreferences = SB.instantiateController(withIdentifier: "radioSelection") as! RadioPreferences
        //PVC.buildStationList(radios: self.radios)
        PVC.station = self.guiClientView
        PVC.preferenceManager = self.preferenceManager
        
        presentAsSheet(PVC)
        // presentAsModalWindow(PVC)
        // present(_ PVC: NSViewController, asPopoverRelativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge, behavior: NSPopover.Behavior)
        
    }
    
} // end class

