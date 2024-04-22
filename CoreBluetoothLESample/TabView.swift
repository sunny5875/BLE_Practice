//
//  TabView.swift
//  CoreBluetoothLESample
//
//  Created by 현수빈 on 4/22/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            CentralView(viewModel: CentralViewModel())
                .tabItem {
                    Image(systemName: "1.square.fill")
                    Text("Central")
                }
            
            PeripheralView(viewModel: PeripheralViewModel())
                .tabItem {
                    Image(systemName: "2.square.fill")
                    Text("Peripheral")
                }
        }
    }
}
