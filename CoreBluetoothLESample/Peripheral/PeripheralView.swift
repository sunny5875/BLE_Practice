/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 A class to advertise, send notifications and receive data from central looking for transfer service and characteristic.
 */

import SwiftUI
import CoreBluetooth
import os


struct PeripheralView: View {
    @StateObject var viewModel: PeripheralViewModel
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(content: {
                    Text(viewModel.receiveMessage)
                }, header: {
                    Text("받은 메세지")
                        .onLongPressGesture {
                            UIPasteboard.general.string = viewModel.receiveMessage
                        }
                })
                
                Section(content: {
                    Toggle(isOn: $viewModel.isOn, label: {
                        Text("블루투스 시작")
                    })
                    TextEditor(text: $viewModel.sendMessage)
                        .focused($isFocused, equals: true)
                    Button(action: {
                        UIApplication.shared.endEditing()
                    }, label: {
                        Text("완료")
                    })
                    
                }, header: {
                    Text("보내기")
                })
            }
            .onAppear {
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.onDisappear()
            }
            .navigationTitle("Peripheral")
        }
    }
}

