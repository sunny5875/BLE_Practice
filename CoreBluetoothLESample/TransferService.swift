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

extension TransferService {
    
    static let mockMessage = """
            {
                "presentation": {
                    "type": "verifiablePresentation",
                    "id": "did:waff:W6hLpTWEbsUW/0Hs6NglWF3g",
                    "credential": {
                        "type": "verifiableCredential",
                        "issuer": {
                            "name": "한양대학교",
                            "id": "did:waff:TCSw+75WvYTptwNP8q5GxSjQ"
                        },
                        "issuanceDate": "1705900000",
                        "expirationDate": "1706900000",
                        "credentialSubjects": {
                            "id": "did:waff:W6hLpTWEbsUW/0Hs6NglWF3g",
                            "name": "홍길순",
                            "subjects": [{
                                "document": {
                                    "name": "학생증",
                                    "contents": [
                                        { "key": "이름", "value": "홍길순" },
                                        { "key": "학번", "value": "2018380355" },
                                        { "key": "학과", "value": "컴퓨터소프트웨어학과" },
                                        { "key": "입학년월", "value": "2018.03" }
                                    ]
                                }
                            }]
                        },
                        "proof": {
                            "signatureAlgorithm": "secp256k1",
                            "created": "1705900000",
                            "creatorID": "did:waff:TCSw+75WvYTptwNP8q5GxSjQ",
                            "jws": "MEUCIQCKWDIAJQbnt/t42k0NHfJu6xpEX5QwDbNaIUBgPT1oCgIgE9rZQqPRW+uIjkXltzbMOfZqib43IxKMCmJ0WjDTXOo="
                        },
                        "verifier": {
                            "name": "김현아",
                            "id": "did:waff:Xz02rvh0jnQMa0IQEywY0LSQ"
                        }
                    },
                    "proof": {
                        "signatureAlgorithm": "secp256k1",
                        "created": "1706000000",
                        "creatorID": "did:waff:W6hLpTWEbsUW/0Hs6NglWF3g",
                        "jws": "MEQCIBrDHgn7j+XQkQZom2NywbA/aNJxswk2zjwb/7eMrYEaAiBjN45eLYO7jx69IaceDzhTWEF+kx//URLDY/GAnEmvvA=="
                    }
                    
                },
    
                  "vc_certificaiton ": {
                    "certificationName": "한양대학교의 인증서",
                    "signatureAlgorithm": "secp256k1",
                    "id": "did:waff:TCSw+75WvYTptwNP8q5GxSjQ",
                    "name": "한양대학교",
                    "pubKey": "-----BEGIN PUBLIC KEY-----\nMFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAEomGvR5L0DkjzBoqVs8ObPXoJYERnn/Ktmjpd0Dcc9LxUd4aCnHVB5UuRV4xDqUTCSw+75WvYTptwNP8q5GxSjQ==\n-----END PUBLIC KEY-----",
                    "created": "1705923040"
                },
    
                "vp_certification": {
                    "certificationName": "홍길순의 인증서",
                    "signatureAlgorithm": "secp256k1",
                    "id": "did:waff:W6hLpTWEbsUW/0Hs6NglWF3g",
                    "name": "홍길순",
                    "pubKey": "-----BEGIN PUBLIC KEY-----\nMFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAESnJ+xVVzWWs0zIJiUJEsPvvnZFBLdCRPAo1eNcP0ouE5gQIhL1Q/ykhLSQHozSW6hLpTWEbsUW/0Hs6NglWF3g==\n-----END PUBLIC KEY-----",
                    "created": "1705923050"
                }
            }
    """
}
