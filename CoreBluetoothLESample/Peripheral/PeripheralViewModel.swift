//
//  PeripheralViewModel.swift
//  CoreBluetoothLESample
//
//  Created by 현수빈 on 4/22/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import CoreBluetooth
import OSLog
import Combine

class PeripheralViewModel: NSObject, ObservableObject {
    
    private var store = Set<AnyCancellable>()
    @Published var isOn = false
    @Published var sendMessage = TransferService.mockMessage
    @Published var receiveMessage = ""
    
    var peripheralManager: CBPeripheralManager!
    
    var receiveCharacteristic: CBMutableCharacteristic?
    var sendCharacteristic: CBMutableCharacteristic?
    var connectedCentral: CBCentral?
    var dataToSend = Data()
    var sendDataIndex: Int = 0
    static var sendingEOM = false
    
    func viewDidLoad() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
        
        $isOn.sink { value in
            if value {
                self.setupPeripheral()
                self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [TransferService.serviceUUID]])
            } else {
                self.peripheralManager.stopAdvertising()
            }
        }.store(in: &store)
    }
    
    func viewWillDisappear() {
        peripheralManager.stopAdvertising()
        receiveMessage.removeAll()
        PeripheralViewModel.sendingEOM = false
    }
}


extension PeripheralViewModel {
    
    private func sendData() {
        guard let sendCharacteristic, let connectedCentral else {
            return
        }
        
        if PeripheralViewModel.sendingEOM {
            let didSend = peripheralManager.updateValue(TransferService.eomToken.data(using: .utf8)!, for: sendCharacteristic, onSubscribedCentrals: [connectedCentral])
            if didSend {
                PeripheralViewModel.sendingEOM = false
                os_log("Sent: /EOM")
            }
            return
        }
        
        if sendDataIndex >= dataToSend.count {
            return
        }
        
        var didSend = true
        while didSend {
            var amountToSend = dataToSend.count - sendDataIndex
            let mtu = connectedCentral.maximumUpdateValueLength
            amountToSend = min(amountToSend, mtu)
            let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))
            
            didSend = peripheralManager.updateValue(chunk, for: sendCharacteristic, onSubscribedCentrals: [connectedCentral])
            
            if !didSend {
                return
            }
            
            let stringFromData = String(data: chunk, encoding: .utf8)
            os_log("Sent %d bytes: %s", chunk.count, String(describing: stringFromData))
            
            sendDataIndex += amountToSend
            
            if sendDataIndex >= dataToSend.count {// 마지막인 경우
                PeripheralViewModel.sendingEOM = true
                let eomSent = peripheralManager.updateValue(TransferService.eomToken.data(using: .utf8)!,
                                                            for: sendCharacteristic, onSubscribedCentrals: nil)
                
                if eomSent {
                    PeripheralViewModel.sendingEOM = false
                    os_log("Sent: /EOM")
                }
                return
            }
        }
    }
    
    private func setupPeripheral() {
        let transferService = CBMutableService(type: TransferService.serviceUUID, primary: true)
        
        let transferCharacteristic = CBMutableCharacteristic(type: TransferService.receiveCharacteristicUUID,
                                                             properties: [.writeWithoutResponse, .write],
                                                             value: nil,
                                                             permissions: [.writeable])
        
        let transferCharacteristic2 = CBMutableCharacteristic(type: TransferService.sendCharacteristicUUID,
                                                              properties: [.notify, .read],
                                                              value: nil,
                                                              permissions: [.readable])
        
        transferService.characteristics = [transferCharacteristic2, transferCharacteristic]
        
        peripheralManager.add(transferService)
        
        self.sendCharacteristic = transferCharacteristic2
        self.receiveCharacteristic = transferCharacteristic
    }
}

extension PeripheralViewModel: CBPeripheralManagerDelegate {
    internal func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        isOn = peripheral.state == .poweredOn
        switch peripheral.state {
        case .poweredOn:
            os_log("CBManager is powered on")
        case .poweredOff:
            os_log("CBManager is not powered on")
        case .resetting:
            os_log("CBManager is resetting")
        case .unauthorized:
            os_log("You are not authorized to use Bluetooth")
        case .unknown:
            os_log("CBManager state is unknown")
        case .unsupported:
            os_log("Bluetooth is not supported on this device")
        @unknown default:
            os_log("A previously unknown peripheral manager state occurred")
        }
    }
    
    /// subscribe 시작하는 경우
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        os_log("Central subscribed to characteristic")
        dataToSend = sendMessage.data(using: .utf8)!
        sendDataIndex = 0
        connectedCentral = central
        sendData()
    }
    
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        if let error {
            NSLog(error.localizedDescription )
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        os_log("Central unsubscribed from characteristic")
        connectedCentral = nil
    }

    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendData()
    }
    
    /// 데이터를 받은 경우
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        
        for aRequest in requests {
            guard let requestValue = aRequest.value,
                  let stringFromData = String(data: requestValue, encoding: .utf8) else {
                continue
            }
            os_log("Received write request of %d bytes: %s", requestValue.count, stringFromData)
            receiveMessage += stringFromData
        }
    }
}

