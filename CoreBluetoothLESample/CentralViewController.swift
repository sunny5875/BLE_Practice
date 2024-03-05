/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 A class to discover, connect, receive notifications and write data to peripherals by using a transfer service and characteristic.
 */

import UIKit
import CoreBluetooth
import os

class CentralViewController: UIViewController {
    
    @IBOutlet var textView: UITextView!
    @IBOutlet weak var tableVIew: UITableView!
    
    private var centralManager: CBCentralManager! // 기기를 검색하고 관리하는 변수
    private var discoveredPeripheral: [(String, CBPeripheral)] = [] { // 발견한 기기들 목록, 기기 이름과 기기로 구성된 리스트
        didSet {
            self.tableVIew.reloadData()
        }
    }
    private var transferCharacteristic: CBCharacteristic?
    private var writeIterationsComplete = 0
    private var connectionIterationsComplete = 0
    private let defaultIterations = 100 // 기기 검색 횟수
    
    private var data: [Data] = [] // 받은 데이터 리스트, 일대다를 위해 data 리스트임
    
    override func viewDidLoad() {
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        super.viewDidLoad()
        
        self.tableVIew.dataSource = self
        self.tableVIew.delegate = self
        self.textView.layer.cornerRadius = 20
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        centralManager.stopScan()
        os_log("Scanning stopped")
        data.removeAll(keepingCapacity: false)
    }
    
    /// 기기를 수신, 현재는 안드로이드 검색을 위해 모든 서비스를 검색하게 풀어둠
    private func retrievePeripheral() {
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        //        let connectedPeripherals: [CBPeripheral] = (centralManager.retrieveConnectedPeripherals(withServices: [TransferService.serviceUUID]))
        //
        //        os_log("Found connected Peripherals with transfer service: %@", connectedPeripherals)
        //        if !connectedPeripherals.isEmpty {
        //            os_log("Connecting to peripheral %@", connectedPeripherals)
        //            self.discoveredPeripheral = connectedPeripherals
        //            connectedPeripherals.forEach {
        //                if !discoveredPeripheral.contains($0) {
        //                    centralManager.connect($0, options: nil)
        //                }
        //            }
        //        } else {
        //            // We were not connected to our counterpart, so start scanning
        //            centralManager.scanForPeripherals(withServices: [TransferService.serviceUUID],
        //                                               options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        //        }
    }
    
    private func cleanup() {
        guard discoveredPeripheral.count != 0 else { return }
        for peripheral in discoveredPeripheral {
            for service in (peripheral.1.services ?? [] as [CBService]) {
                for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
                    if characteristic.isNotifying { // && characteristic.uuid == TransferService.characteristicUUID
                        peripheral.1.setNotifyValue(false, for: characteristic)
                    }
                }
            }
            centralManager.cancelPeripheralConnection(peripheral.1)
        }
    }
    
    // peripherial에게 받은 데이터를 UI에 보여주기
    private func writeData(peripheral: CBPeripheral) {
        guard let transferCharacteristic = transferCharacteristic
        else { return }
        
        while writeIterationsComplete < defaultIterations && peripheral.canSendWriteWithoutResponse {
            let mtu = peripheral.maximumWriteValueLength (for: .withoutResponse)
            var rawPacket = [UInt8]()
            
            let bytesToCopy: size_t = min(mtu, data.count)
            data.last?.copyBytes(to: &rawPacket, count: bytesToCopy)
            
            let deviceName = peripheral.name ?? "기기이름" + ": "
            let deviceData = deviceName.data(using: .utf8) ?? Data()
            
            var packetData: Data = deviceData
            packetData.append(Data(bytes: &rawPacket, count: bytesToCopy))
            
            let stringFromData = String(data: packetData, encoding: .utf8)
            os_log("%s:Writing %d bytes: %s", deviceName, bytesToCopy, String(describing: stringFromData))
            
            peripheral.writeValue(packetData, for: transferCharacteristic, type: .withoutResponse)
            
            writeIterationsComplete += 1
            
        }
     if writeIterationsComplete == defaultIterations {
         peripheral.setNotifyValue(false, for: transferCharacteristic)
     }
  }
}

extension CentralViewController: CBCentralManagerDelegate {
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
            switch central.authorization {
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
            os_log("A previously unknown central manager state occurred")
        }
    }
    /// central에서 peripherial 기기를 발견한 경우
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // 신호가 약한 경우 거르기
        guard RSSI.intValue >= -100 else { return }
        
        // 연결되지 않은 기기의 경우 name이 안뜨는 경우도 있어 CBAdvertisementDataLocalNameKey로 가져오기
        guard let peripheralName = peripheral.name ??
                                   (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
        else { return }
        
        os_log("Discovered %s, UUID: %s %d", peripheralName, peripheral.identifier.uuidString, peripheral.ancsAuthorized)
        
        if !discoveredPeripheral.map({$0.1}).contains(peripheral) {
            discoveredPeripheral.append((peripheralName, peripheral))
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        os_log("Failed to connect to %@. %s", peripheral, String(describing: error))
        cleanup()
    }
    /// peripheral과 연결된 경우
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Peripheral Connected")
        
        connectionIterationsComplete += 1
        writeIterationsComplete = 0
        
        data.removeAll(keepingCapacity: false)
        
        peripheral.delegate = self
//        peripheral.discoverServices([TransferService.serviceUUID])
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        os_log("Perhiperal Disconnected")
        discoveredPeripheral = []
        
        if connectionIterationsComplete < defaultIterations {
            retrievePeripheral()
        } else {
            os_log("Connection iterations completed")
        }
    }
    
}

extension CentralViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        for service in invalidatedServices { // where service.uuid == TransferService.serviceUUID {
            os_log("Transfer service is invalidated - rediscover services")
//            peripheral.discoverServices([TransferService.serviceUUID])
            peripheral.discoverServices(nil)
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
            peripheral.discoverCharacteristics([TransferService.characteristicUUID], for: service)
//            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    /// characteristics를 찾은 경우
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            os_log("Error discovering characteristics: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        guard let serviceCharacteristics = service.characteristics else { return }
        for characteristic in serviceCharacteristics {// where characteristic.uuid == TransferService.characteristicUUID {
            transferCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            os_log("Error discovering characteristics: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        guard let characteristicData = characteristic.value,
              let stringFromData = String(data: characteristicData, encoding: .utf8) else { return }
        
        os_log("Received %d bytes: %s", characteristicData.count, stringFromData)
        
        if stringFromData == "EOM" {
            DispatchQueue.main.async() {
                let text = (peripheral.name ?? "기기이름") + ": " + (String(data: self.data.last ?? Data(), encoding: .utf8) ?? "") + "\n"
                self.textView.text += text
            }
//            writeData(peripheral: peripheral)
        } else {
            data.append(characteristicData)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            os_log("Error changing notification state: %s", error.localizedDescription)
            return
        }
//        guard characteristic.uuid == TransferService.characteristicUUID else { return }
        if characteristic.isNotifying {
            os_log("Notification began on %@", characteristic)
        } else {
            os_log("Notification stopped on %@. Disconnecting", characteristic)
            cleanup()
        }
        
    }
    
    /*
     *  This is called when peripheral is ready to accept more data when using write without response
     func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
     os_log("Peripheral is ready, send data")
     writeData(peripheral: peripheral)
     }
     */
}

extension CentralViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredPeripheral.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: .none)
        cell.textLabel?.text = discoveredPeripheral[indexPath.row].0
        cell.detailTextLabel?.text = discoveredPeripheral[indexPath.row].1.identifier.uuidString
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripherial = discoveredPeripheral[indexPath.row]
        centralManager.connect(peripherial.1, options: .none)
    }
}
