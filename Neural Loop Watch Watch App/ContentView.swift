//
//  ContentView.swift
//  Neural Loop Watch Watch App
//
//  Created by Sanjeev Hayal on 23/01/2026.
//

import SwiftUI

struct ContentView: View {
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    NavigationLink(value: WatchTab.home) {
                        VStack {
                            Image(systemName: "house.fill")
                                .font(.title)
                            Text("Home")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                    }
                    
                    NavigationLink(value: WatchTab.fitness) {
                        VStack {
                            Image(systemName: "figure.run")
                                .font(.title)
                            Text("Fitness")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Neural Loop")
            .navigationDestination(for: WatchTab.self) { tab in
                switch tab {
                case .home:
                    VStack {
                        Image(systemName: "house.fill")
                            .font(.largeTitle)
                        Text("Coming Soon")
                            .font(.headline)
                        Text("Your personalized neural loop dashboard.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .navigationTitle("Home")
                case .fitness:
                    WatchFitnessView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
