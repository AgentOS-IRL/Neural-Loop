//
//  GoalsUDM.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 17/01/2026.
//

import SwiftUI

extension  UnifiedDataModel {
    
    func getLifeAreaName(lifeArea_id: Int64?) async -> String? {
        if lifeArea_id == nil {return nil}
        
        if let lifeArea = lifeAreas.first(where: { $0.id == lifeArea_id! }) {
            return lifeArea.name
        }
        
        return nil
    }
    
    func getSubGoals(forPatentId: Int64) -> [Goals]{
        return goals.filter({$0.parent_id == forPatentId})
    }
    
    func getGoalName(goal_id: Int64?) async -> String? {
        if goal_id == nil {return nil}
        
        if let goal = goals.first(where: { $0.id == goal_id! }) {
            return goal.title
        }
        
        return nil
    }
    
    func toggleExpansion(for id: Int64) {
        if lifeAreaExpandedIds.contains(id) {
            lifeAreaExpandedIds.remove(id)
        } else {
            lifeAreaExpandedIds.insert(id)
        }
    }
    func isExpanded(for id: Int64) -> Bool {
        return lifeAreaExpandedIds.contains(id)
    }
    
 
    
    func getGoalDateBucket() -> [DateBucket] {
        return _longTermGoalsDateBucket
    }
    
    func saveLifeArea(_ lifeArea: LifeAreas) async {
        do {
            let newLifeArea = try await manager.addLifeArea(lifeArea)
            lifeAreas.append(newLifeArea)
        }
        catch {
            print("Error saving life area: \(error)")
        }
    }
    
    func updateLifeAreaVision(id: Int64, vision: String) async{
        do {
            try await manager.updateVision(id: id, vision: vision)
        }
        catch {
            print("Error updating life area: \(error)")
        }
        
    }
    
    func saveGoal(_ goal: Goals) async {
        do {
            let newGoal = try await manager.addGoal(goal)
            goals.append(newGoal)
        }
        catch {
            print("Error saving goal: \(error)")
        }
    }
    
    func updateGoal(_ goal: Goals) async {
        do {
            try await manager.updateGoal(goal)
            if let index = goals.firstIndex(where: { $0.id == goal.id}) {
                goals.remove(at: index)
                goals.insert(goal, at: index)
            }
        }
        catch {
            print("Error updating goal: \(error)")
        }
    }
    
    
    
    func getGoalProgressBar(goalId: Int64, goalTracking: GoalsTracking?, goalTasks: [Tasks]?) -> some View {
        let tracking: GoalsTracking =
        goalTracking
            ?? GoalsTracking(
                id: nil,
                goal_id: goalId,
                type: .custom,
                value: nil,
                target: nil,
                label: nil,
                created_at: nil,
                updated_at: nil
            )

        if tracking.type == .custom {
            return progressMiniBar(
                percentage: Double(tracking.value ?? 0)
                    / Double(tracking.target ?? 1)
            )
        }

        if tracking.type == .task {
            let tasks: [Tasks] = goalTasks ?? []
            let totalCount = tasks.count
            let completedCount = tasks.filter { $0.is_completed }.count

            let percentage: Double =
                totalCount == 0
                ? 0
                : Double(completedCount) / Double(totalCount)
            return progressMiniBar(percentage: percentage)

        }

        if tracking.type == .sub_goal {

            Task {
                let subGoals = getSubGoals(forPatentId: goalId)

                let totalCount = subGoals.count
                let completedCount = subGoals.filter { $0.is_completed }.count

                let percentage: Double =
                    totalCount == 0
                    ? 0
                    : Double(completedCount) / Double(totalCount)
                return progressMiniBar(percentage: percentage)
            }
        }

        return progressMiniBar(percentage: 0)
    }
    
    func fetchGoalsTrackingRecords(
        forTracking trackingId: Int64,
        type: GoalTrackingType
    ) async -> [GoalsTrackingRecord] {
        do {
            return try await manager.fetchGoalsTrackingRecords(
                forTracking: trackingId,
                type: type
            )
        } catch {
            print("Failed to get tracking records: \(error)")
            return []
        }
    }
    
    func createGoalsTrackingRecord(record: GoalsTrackingRecord)
    async {
        do {
            try await manager.createGoalsTrackingRecord(record)
        }
        catch {
            print("Failed to create tracking record: \(error)")
        }
    }
    
    func deleteGoalsTracking(forGoal: Int64) async {
        do {
             try await manager.deleteGoalsTracking(forGoal: forGoal)
        }
        catch {
            print("Failed to delete goal tracking: \(error)")
        }
    }
    
    func createGoalsTracking(_ tracking: GoalsTracking) async {
        do{
            try await manager.createGoalsTracking(tracking)
        }
        catch{
            print("Failed to create goal tracking: \(error)")
        }
    }
    
    func fetchGoalsTracking(forGoal: Int64) async -> GoalsTracking {
        do {
            return try await manager.fetchGoalsTracking(forGoal: forGoal) ?? GoalsTracking.empty
        }
        catch {
            // ignore
            print("Error fetching goal tracking: \(error)")
        }
        return GoalsTracking.empty
        
    }
}
