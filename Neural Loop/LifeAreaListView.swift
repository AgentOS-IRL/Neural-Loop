//
//  LifeAreaListView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation
import SwiftUI

struct LifeAreaListView: View {
    @State private var lifeAreas: [LifeAreas] = []
    @State private var error: String?

    var body: some View {
        NavigationView {
            VStack {
                if let error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }

                List(lifeAreas, id: \.id) { area in
                    VStack(alignment: .leading) {
                        Text(area.name)
                            .font(.headline)
                        Text(area.vision ?? "No Vision Set")
                            .font(.subheadline)
                        Text("Sample: \(area.is_sample ? "Yes" : "No")")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Life Areas")
            .onAppear {
                print("Goals Tab Loading!")
                loadLifeAreas()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func loadLifeAreas() {
        do {
            print("Loading life areas")
            let manager = try DBManager.newInstance()
            lifeAreas = try manager.fetchAllLifeAreas()
            error = nil
        } catch {
            lifeAreas = []
            print(error)
        }
    }
}
