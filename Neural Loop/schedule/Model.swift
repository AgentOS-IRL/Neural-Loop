//
//  model.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation

struct TaskTiming {
    let start: Date
    let duration: TimeInterval
    
    func summary() -> String {
        
        if start == .distantFuture {
            return "Anytime"
        }
        let df = DateFormatter()
        df.timeStyle = .short
        let summary = df.string(from: start)

        if duration > 0 {
            let mins = Int(duration / 60)
            return "\(summary) • \(mins) min"
        }
        return summary
        
    }
}
