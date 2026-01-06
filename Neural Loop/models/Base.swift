//
//  base.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation


struct TaskInput {
    let title: String
    let description: String?
    let priority: Int   // 0 = none, 1 = low, 2 = medium, 3 = high
    let schedule: TaskScheduleDraft?
    let is_deadline: Bool
}
