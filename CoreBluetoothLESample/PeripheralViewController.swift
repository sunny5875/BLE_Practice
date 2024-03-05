/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 A class to advertise, send notifications and receive data from central looking for transfer service and characteristic.
 */

import UIKit
import CoreBluetooth
import os

class PeripheralViewController: UIViewController {
    
    @IBOutlet var textView: UITextView!
    @IBOutlet var advertisingSwitch: UISwitch!
    
    private var peripheralManager: CBPeripheralManager!
    
    private var transferCharacteristic: CBMutableCharacteristic?
    private var connectedCentral: CBCentral?
    private var dataToSend = Data()
    private var sendDataIndex: Int = 0
    
    override func viewDidLoad() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
        super.viewDidLoad()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        peripheralManager.stopAdvertising()
        
        super.viewWillDisappear(animated)
    }
    
    
    @IBAction func switchChanged(_ sender: Any) {
        if advertisingSwitch.isOn {
//            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [TransferService.serviceUUID]])
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: nil])
        } else {
            peripheralManager.stopAdvertising()
        }
    }
    
    static var sendingEOM = false
    
    private func sendData() {
        
        guard let transferCharacteristic = transferCharacteristic else {
            return
        }
        
        if PeripheralViewController.sendingEOM {
            let didSend = peripheralManager.updateValue("EOM".data(using: .utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
            if didSend {
                PeripheralViewController.sendingEOM = false
                os_log("Sent: EOM")
            }
            return
        }
        
        if sendDataIndex >= dataToSend.count {
            return
        }
        
        var didSend = true
        while didSend {
            var amountToSend = dataToSend.count - sendDataIndex
            if let mtu = connectedCentral?.maximumUpdateValueLength {
                amountToSend = min(amountToSend, mtu)
            }
            let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))
            
            didSend = peripheralManager.updateValue(chunk, for: transferCharacteristic, onSubscribedCentrals: nil)
            
            if !didSend {
                return
            }
            
            let stringFromData = String(data: chunk, encoding: .utf8)
            os_log("Sent %d bytes: %s", chunk.count, String(describing: stringFromData))
            
            sendDataIndex += amountToSend
            
            if sendDataIndex >= dataToSend.count {// 마지막인 경우
                PeripheralViewController.sendingEOM = true
                let eomSent = peripheralManager.updateValue("EOM".data(using: .utf8)!,
                                                            for: transferCharacteristic, onSubscribedCentrals: nil)
                
                if eomSent {
                    PeripheralViewController.sendingEOM = false
                    os_log("Sent: EOM")
                }
                return
            }
        }
    }
    
    private func setupPeripheral() {
        let transferCharacteristic = CBMutableCharacteristic(type: TransferService.characteristicUUID,
                                                             properties: [.notify, .writeWithoutResponse],
                                                             value: nil,
                                                             permissions: [.readable, .writeable])
        
        let transferService = CBMutableService(type: TransferService.serviceUUID, primary: true)
        
        transferService.characteristics = [transferCharacteristic]
        peripheralManager.add(transferService)
        self.transferCharacteristic = transferCharacteristic
    }
}

extension PeripheralViewController: CBPeripheralManagerDelegate {
    internal func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        advertisingSwitch.isEnabled = peripheral.state == .poweredOn
        
        switch peripheral.state {
        case .poweredOn:
            os_log("CBManager is powered on")
            setupPeripheral()
        case .poweredOff:
            os_log("CBManager is not powered on")
        case .resetting:
            os_log("CBManager is resetting")
        case .unauthorized:
            switch peripheral.authorization {
            case .denied:
                os_log("You are not authorized to use Bluetooth")
            case .restricted:
                os_log("Bluetooth is restricted")
            default:
                os_log("Unexpected authorization")
            }
        case .unknown:
            os_log("CBManager state is unknown")
        case .unsupported:
            os_log("Bluetooth is not supported on this device")
        @unknown default:
            os_log("A previously unknown peripheral manager state occurred")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        os_log("Central subscribed to characteristic")
        
        dataToSend = textView.text.data(using: .utf8)!
        sendDataIndex = 0
        connectedCentral = central
        sendData()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        os_log("Central unsubscribed from characteristic")
        connectedCentral = nil
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendData()
    }
    
//    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
//        for aRequest in requests {
//            guard let requestValue = aRequest.value,
//                  let stringFromData = String(data: requestValue, encoding: .utf8) else {
//                continue
//            }
//            
//            os_log("Received write request of %d bytes: %s", requestValue.count, stringFromData)
//            self.textView.text = stringFromData
//        }
//    }
}

extension PeripheralViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        // If we're already advertising, stop
        if advertisingSwitch.isOn {
            advertisingSwitch.isOn = false
            peripheralManager.stopAdvertising()
        }
    }
    func textViewDidBeginEditing(_ textView: UITextView) {
        // We need to add this manually so we have a way to dismiss the keyboard
        let rightButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        navigationItem.rightBarButtonItem = rightButton
    }
    @objc
    func dismissKeyboard() {
        textView.resignFirstResponder()
        navigationItem.rightBarButtonItem = nil
    }
}

