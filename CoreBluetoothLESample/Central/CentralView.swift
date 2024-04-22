/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 A class to discover, connect, receive notifications and write data to peripherals by using a transfer service and characteristic.
 */

import SwiftUI
import CoreBluetooth
import os

struct CentralView: View {
    @StateObject var viewModel: CentralViewModel
    
    var body: some View {
        NavigationView {
            Form {
                Section(content: {
                    Text(viewModel.receiveMessage)
                }, header:  {
                    Text("받은 결과")
                        .frame(alignment: .leading)
                })
                
                Section(content: {
                    ForEach(viewModel.discoveredPeripheral, id: \.1.identifier) { (name, peripheral) in
                        cell(name: name,peripheral: peripheral)
                            .onTapGesture {
                                viewModel.connect(peripheral: peripheral)
                            }
                    }
                }, header: {
                    Text("발견된 기기 리스트")
                })
            }
            .navigationTitle("Central")
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisAppear()
        }
    }
    
    @ViewBuilder
    func cell(name: String, peripheral: CBPeripheral) -> some View{
        VStack(alignment: .leading) {
            Text(name)
                .font(.body)
            Text(peripheral.identifier.uuidString)
                .font(.caption)
        }
    }
    
}
