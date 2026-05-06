//
//  Neural_Loop_WidgetsBundle.swift
//  Neural Loop Widgets
//
//  Created by Sanjeev Halyal on 28/04/26.
//

import WidgetKit
import SwiftUI

@main
struct Neural_Loop_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        NeuralLoopActionsWidget()
        NeuralLoopCalendarWidget()
        WorkoutLiveActivity()
    }
}
