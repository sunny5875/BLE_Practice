/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Transfer service and characteristics UUIDs
*/

import Foundation
import CoreBluetooth

struct TransferService {
	static let serviceUUID = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
    // periperal 기준 characteristicUUID
	static let receiveCharacteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")
    static let sendCharacteristicUUID = CBUUID(string: "8c380001-10bd-4fdb-ba21-1922d6cf860d")
    
    static let eomToken = "/EOM"
}
