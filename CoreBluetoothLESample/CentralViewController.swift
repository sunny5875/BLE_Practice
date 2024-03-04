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
    
    var centralManager: CBCentralManager!
    
    var discoveredPeripheral: [(String, CBPeripheral)] = [] {
        didSet {
            self.tableVIew.reloadData()
        }
    }
    var transferCharacteristic: CBCharacteristic?
    var writeIterationsComplete = 0
    var connectionIterationsComplete = 0
    
    let defaultIterations = 100
    
    var data: [Data] = []
    
    
    // MARK: - view lifecycle
    
    override func viewDidLoad() {
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        super.viewDidLoad()
        
        self.tableVIew.dataSource = self
        self.tableVIew.delegate = self
        
        self.textView.layer.cornerRadius = 20
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Don't keep it going while we're not showing.
        centralManager.stopScan()
        os_log("Scanning stopped")
        
        data.removeAll(keepingCapacity: false)
        
        super.viewWillDisappear(animated)
    }
    
    // MARK: - Helper Methods
    
    /*
     * We will first check if we are already connected to our counterpart
     * Otherwise, scan for peripherals - specifically for our service's 128bit CBUUID
     */
    private func retrievePeripheral() {
        
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        //        let connectedPeripherals: [CBPeripheral] = (centralManager.retrieveConnectedPeripherals(withServices: [TransferService.serviceUUID]))
        //
        //        os_log("Found connected Peripherals with transfer service: %@", connectedPeripherals)
        //
        //        if !connectedPeripherals.isEmpty {
        //            os_log("Connecting to peripheral %@", connectedPeripherals)
        //			self.discoveredPeripheral = connectedPeripherals
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
    
    /*
     *  Call this when things either go wrong, or you're done with the connection.
     *  This cancels any subscriptions if there are any, or straight disconnects if not.
     *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
     */
    private func cleanup() {
        // Don't do anything if we're not connected
        guard discoveredPeripheral.count != 0 else { return }
        for peripheral in discoveredPeripheral {
            for service in (peripheral.1.services ?? [] as [CBService]) {
                for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
                    //                    if characteristic.uuid == TransferService.characteristicUUID && characteristic.isNotifying {
                    //                        // It is notifying, so unsubscribe
                    //                        peripheral.setNotifyValue(false, for: characteristic)
                    //                    }
                    if characteristic.isNotifying {
                        peripheral.1.setNotifyValue(false, for: characteristic)
                    }
                }
            }
            // If we've gotten this far, we're connected, but we're not subscribed, so we just disconnect
            centralManager.cancelPeripheralConnection(peripheral.1)
        }
        
        
    }
    
    /*
     *  Write some test data to peripheral
     */
     private func writeData(peripheral: CBPeripheral) {
     
     guard let transferCharacteristic = transferCharacteristic
     else { return }
     
     // check to see if number of iterations completed and peripheral can accept more data
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
         // Cancel our subscription to the characteristic
         peripheral.setNotifyValue(false, for: transferCharacteristic)
     }
  }
    
    
}

/// implementations of the CBCentralManagerDelegate methods
extension CentralViewController: CBCentralManagerDelegate {
    /*
     *  centralManagerDidUpdateState is a required protocol method.
     *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
     *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
     *  the Central is ready to be used.
     */
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .poweredOn:
            os_log("CBManager is powered on")
            retrievePeripheral()
        case .poweredOff:
            os_log("CBManager is not powered on")
            return
        case .resetting:
            os_log("CBManager is resetting")
            return
        case .unauthorized:
            if #available(iOS 13.0, *) {
                switch central.authorization {
                case .denied:
                    os_log("You are not authorized to use Bluetooth")
                case .restricted:
                    os_log("Bluetooth is restricted")
                default:
                    os_log("Unexpected authorization")
                }
            } else {
                // Fallback on earlier versions
            }
            return
        case .unknown:
            os_log("CBManager state is unknown")
            return
        case .unsupported:
            os_log("Bluetooth is not supported on this device")
            return
        @unknown default:
            os_log("A previously unknown central manager state occurred")
            return
        }
    }
    
    /*
     *  This callback comes whenever a peripheral that is advertising the transfer serviceUUID is discovered.
     *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
     *  we start the connection process
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // 전력 세기에 따른 guard
        guard RSSI.intValue >= -100
        else {
            return
        }
        
        guard let peripheralName = peripheral.name ??
                                    (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
        else { return }
               
        os_log("Discovered %s, UUID: %s %d", peripheralName, peripheral.identifier.uuidString, peripheral.ancsAuthorized)
        
        if !discoveredPeripheral.map({$0.1}).contains(peripheral) {
            discoveredPeripheral.append((peripheralName, peripheral))
        }
    }
    
    /*
     *  If the connection fails for whatever reason, we need to deal with it.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        os_log("Failed to connect to %@. %s", peripheral, String(describing: error))
        cleanup()
    }
    
    /*
     *  We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Peripheral Connected")
        
        // set iteration info
        connectionIterationsComplete += 1
        writeIterationsComplete = 0
        
        // Clear the data that we may already have
        data.removeAll(keepingCapacity: false)
        
        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only for services that match our UUID
        //        peripheral.discoverServices([TransferService.serviceUUID])
        peripheral.discoverServices(nil)
    }
    
    /*
     *  Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        os_log("Perhiperal Disconnected")
        discoveredPeripheral = []
        
        // We're disconnected, so start scanning again
        if connectionIterationsComplete < defaultIterations {
            retrievePeripheral()
        } else {
            os_log("Connection iterations completed")
        }
    }
    
}

extension CentralViewController: CBPeripheralDelegate {
    /*
     *  The peripheral letting us know when services have been invalidated.
     */
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        for service in invalidatedServices { //where service.uuid == TransferService.serviceUUID {
            os_log("Transfer service is invalidated - rediscover services")
//            peripheral.discoverServices([TransferService.serviceUUID])
            peripheral.discoverServices(nil)
        }
    }
    
    /*
     *  The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            os_log("Error discovering services: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        guard let peripheralServices = peripheral.services else { return }
        for service in peripheralServices {
            //            peripheral.discoverCharacteristics([TransferService.characteristicUUID], for: service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    /*
     *  The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any).
        if let error = error {
            os_log("Error discovering characteristics: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        // Again, we loop through the array, just in case and check if it's the right one
        guard let serviceCharacteristics = service.characteristics else { return }
        for characteristic in serviceCharacteristics {//where characteristic.uuid == TransferService.characteristicUUID {
            // If it is, subscribe to it
            transferCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    /*
     *   This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            os_log("Error discovering characteristics: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        guard let characteristicData = characteristic.value,
              let stringFromData = String(data: characteristicData, encoding: .utf8) else { return }
        
        os_log("Received %d bytes: %s", characteristicData.count, stringFromData)
        
        // Have we received the end-of-message token?
        if stringFromData == "EOM" {
            // End-of-message case: show the data.
            // Dispatch the text view update to the main queue for updating the UI, because
            // we don't know which thread this method will be called back on.
            DispatchQueue.main.async() {
                let text = (peripheral.name ?? "기기이름") + ": " + (String(data: self.data.last ?? Data(), encoding: .utf8) ?? "") + "\n"
                
                self.textView.text += text
                
            }
            
            // Write test data
            writeData(peripheral: peripheral)
        } else {
            // Otherwise, just append the data to what we have previously received.
            data.append(characteristicData)
        }
    }
    
    /*
     *  The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            os_log("Error changing notification state: %s", error.localizedDescription)
            return
        }
        
        // Exit if it's not the transfer characteristic
//        guard characteristic.uuid == TransferService.characteristicUUID else { return }
        
        if characteristic.isNotifying {
            // Notification has started
            os_log("Notification began on %@", characteristic)
        } else {
            // Notification has stopped, so disconnect from the peripheral
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
