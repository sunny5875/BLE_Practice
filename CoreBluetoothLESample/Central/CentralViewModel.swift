//
//  CentralViewModel.swift
//  CoreBluetoothLESample
//
//  Created by 현수빈 on 4/22/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import OSLog
import CoreBluetooth
import Combine

class CentralViewModel: NSObject, ObservableObject {
    var centralManager: CBCentralManager! // 기기를 검색하고 관리하는 변수
    @Published var discoveredPeripheral: [(String, CBPeripheral)] = []  // 발견한 기기들 목록, 기기 이름과 기기로 구성된 리스트
    @Published var receiveMessage = ""
    
    var receiveCharacteristic: CBCharacteristic?
    var sendCharacteristic: CBCharacteristic?
    var currentConnectionCount = 0
    let maximumConnectionCount = 10
    
    
    var dataList: [Data] = []
    let sendMessage = "I am central"
    
    func onAppear() {
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    
    func onDisAppear() {
        receiveMessage.removeAll()
        centralManager.stopScan()
        discoveredPeripheral.removeAll()
        os_log("Scanning stopped")
        dataList.removeAll(keepingCapacity: false)
    }
    
    func connect(peripheral: CBPeripheral) {
        centralManager.connect(peripheral, options: .none)
    }
    
    private func cleanup(uuid: String? = .none) {
        guard discoveredPeripheral.count != 0 else { return }
        
        for peripheral in discoveredPeripheral {
            for service in (peripheral.1.services ?? [] as [CBService]) {
                for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
                    if characteristic.isNotifying {
                        if let uuid,
                           (String(characteristic.uuid.uuidString) == uuid) {
                            peripheral.1.setNotifyValue(false, for: characteristic)
                            return
                        } else {
                            peripheral.1.setNotifyValue(false, for: characteristic)
                        }
                    }
                }
            }
            centralManager.cancelPeripheralConnection(peripheral.1)
        }
    }
    
    private func retrievePeripheral() {
        let scanOptions: [String: Any] = [
            CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [],
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ]
        centralManager.scanForPeripherals(withServices: [TransferService.serviceUUID], options: scanOptions)
    }
    
}

extension CentralViewModel: CBCentralManagerDelegate {
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            os_log("CBManager is powered on")
            retrievePeripheral()
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
            os_log("A previously unknown central manager state occurred")
        }
    }
    /// central에서 peripherial 기기를 발견한 경우
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // 신호가 약한 경우 거르기
        guard RSSI.intValue >= -80 else { return }
        
        // 연결되지 않은 기기의 경우 name이 안뜨는 경우도 있어 CBAdvertisementDataLocalNameKey로 가져오기
        let peripheralName = peripheral.name ??
        (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Unnamed"
        
        os_log("Discovered %s, UUID: %s %d", peripheralName, peripheral.identifier.uuidString, peripheral.ancsAuthorized)
        
        if !discoveredPeripheral.map({$0.1.identifier}).contains(peripheral.identifier) {
            discoveredPeripheral.append((peripheralName, peripheral))
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        os_log("Failed to connect to %@. %s", peripheral, String(describing: error))
        cleanup()
    }
    
    /// peripheral과 연결된 경우 service 검색
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Peripheral Connected")
        
        currentConnectionCount += 1
        
        dataList.removeAll(keepingCapacity: false)
        peripheral.delegate = self
        peripheral.discoverServices([TransferService.serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        os_log("Perhiperal Disconnected")
        discoveredPeripheral.removeAll(where: {$0.0 == peripheral.identifier.uuidString})
        currentConnectionCount -= 1
        
        if currentConnectionCount < maximumConnectionCount {
            retrievePeripheral()
        } else {
            os_log("Connection iterations completed")
        }
    }
    
}

extension CentralViewModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        for service in invalidatedServices  where service.uuid == TransferService.serviceUUID {
            os_log("Transfer service is invalidated - rediscover services")
            peripheral.discoverServices([TransferService.serviceUUID])
        }
    }
    /// service를 발견한 경우
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            os_log("Error discovering services: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        guard let peripheralServices = peripheral.services else { return }
        for service in peripheralServices {
            peripheral.discoverCharacteristics([
                TransferService.receiveCharacteristicUUID,
                TransferService.sendCharacteristicUUID
            ], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == TransferService.sendCharacteristicUUID {
                    receiveCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    peripheral.readValue(for: characteristic)
                    
                } else if characteristic.uuid == TransferService.receiveCharacteristicUUID {
                    sendCharacteristic = characteristic
                    let data = sendMessage.data(using: .utf8)
                    peripheral.writeValue(data!, for: characteristic, type: .withResponse)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            os_log("Error discovering characteristics: %s", error.localizedDescription)
            //            cleanup(uuid: characteristic.uuid.uuidString)
            return
        }
        
        guard let characteristicData = characteristic.value,
              let stringFromData = String(data: characteristicData, encoding: .utf8) else { return }
        
        os_log("Received %d bytes: %s", characteristicData.count, stringFromData)
        
        DispatchQueue.main.async() {
            guard !stringFromData.contains(TransferService.eomToken) else { return }
            self.receiveMessage += stringFromData
            self.dataList.append(characteristicData)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            os_log("Error changing notification state: %s", error.localizedDescription)
            return
        }
        if characteristic.isNotifying {
            os_log("Notification began on %@", characteristic)
        } else {
            os_log("Notification stopped on %@. Disconnecting", characteristic)
            //            cleanup(uuid: characteristic.uuid.uuidString)
        }
    }
}
