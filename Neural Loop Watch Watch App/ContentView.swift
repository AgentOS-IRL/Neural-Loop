//
//  ContentView.swift
//  Neural Loop Watch Watch App
//
//  Created by Sanjeev Hayal on 23/01/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("iPhone says:")
            Text(ConnectivityManager.shared.receivedMessage)

            Button("Send Hello") {
                print("Sending to Iphone...")
                ConnectivityManager.shared.sendMessage("Hello from Watch 👋")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
