//
//  GoalsUDM.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 17/01/2026.
//

import SwiftUI

extension  UnifiedDataModel {

    // MARK: - Goal Functions
    func getGoal(by goalId: Int64) -> Goals? {
        return goals.first { $0.id == goalId }
    }

    func getGoals(lifeAreaId: Int64) -> [Goals] {
        return goals.filter { $0.lifearea_id == lifeAreaId }
    }


    func getGoalTracking(goalId:Int64) -> GoalsTracking? {
        return goalTracking.first(where: { $0.goal_id == goalId }) ?? nil
    }

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

    func updateLifeArea(_ lifeArea: LifeAreas) async {
        do {
            try await manager.updateLifeArea(lifeArea)
            if let index = lifeAreas.firstIndex(where: { $0.id == lifeArea.id }) {
                lifeAreas.remove(at: index)
                lifeAreas.insert(lifeArea, at: index)
            }
        }
        catch {
            print("Error updating life area: \(error)")
        }
    }

    func updateLifeAreaVision(id: Int64, vision: String) async -> Bool {
        do {
            try await manager.updateVision(id: id, vision: vision)
            if let index = lifeAreas.firstIndex(where: { $0.id == id }) {
                var updatedArea = lifeAreas[index]
                updatedArea.vision = vision
                lifeAreas.remove(at: index)
                lifeAreas.insert(updatedArea, at: index)
            }
            return true
        }
        catch {
            print("Error updating life area: \(error)")
            return false
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

    func deleteGoal(_ goal: Goals) async {
        guard let goalId = goal.id else { return }
        do {
            try await manager.deleteGoal(id: goalId)
            goals.removeAll { $0.id == goalId }
            goalTracking.removeAll { $0.goal_id == goalId }
            removeGoalsFromLongTermBuckets(goalIds: [goalId])
        }
        catch {
            print("Error deleting goal: \(error)")
        }
    }

    func deleteLifeArea(_ lifeArea: LifeAreas) async {
        guard let lifeAreaId = lifeArea.id else { return }
        do {
            let removedGoalIds = goals
                .filter { $0.lifearea_id == lifeAreaId }
                .compactMap(\.id)
            let removedGoalIdSet = Set(removedGoalIds)
            let taskBelongsToDeletedLifeArea: (Tasks) -> Bool = { task in
                task.lifearea_id == lifeAreaId ||
                task.goal_id.map { removedGoalIdSet.contains($0) } == true
            }
            let habitBelongsToDeletedLifeArea: (Habits) -> Bool = { habit in
                habit.lifearea_id == lifeAreaId ||
                habit.goal_id.map { removedGoalIdSet.contains($0) } == true
            }
            let removedTaskIds = tasks
                .filter(taskBelongsToDeletedLifeArea)
                .compactMap(\.id)
            let removedHabitIds = habits
                .filter(habitBelongsToDeletedLifeArea)
                .compactMap(\.id)

            try await manager.deleteLifeArea(id: lifeAreaId)

            for taskId in removedTaskIds {
                await notificationScheduler.clearTaskNotifications(taskId: taskId)
            }
            for habitId in removedHabitIds {
                await notificationScheduler.clearHabitNotifications(habitId: habitId)
            }

            lifeAreas.removeAll { $0.id == lifeAreaId }
            lifeAreaExpandedIds.remove(lifeAreaId)
            goals.removeAll { $0.lifearea_id == lifeAreaId }
            goalTracking.removeAll { tracking in
                removedGoalIds.contains(tracking.goal_id)
            }
            tasks.removeAll(where: taskBelongsToDeletedLifeArea)
            habits.removeAll(where: habitBelongsToDeletedLifeArea)
            removeGoalsFromLongTermBuckets(goalIds: removedGoalIds)
        }
        catch {
            print("Error deleting life area: \(error)")
        }
    }

    private func removeGoalsFromLongTermBuckets(goalIds: [Int64]) {
        guard !goalIds.isEmpty else { return }
        let goalIdSet = Set(goalIds)
        for index in _longTermGoalsDateBucket.indices {
            _longTermGoalsDateBucket[index].ids.removeAll { goalIdSet.contains($0) }
        }
    }



    func getGoalProgressBar(
        goalId: Int64,
        goalTracking: GoalsTracking?,
        goalTasks: [Tasks]?,
        subGoals: [Goals]? = nil
    ) -> some View {
        let snapshot = GoalProgressCalculator.snapshot(
            goalId: goalId,
            tracking: goalTracking,
            tasks: goalTasks ?? getTasks(goalId: goalId),
            subGoals: subGoals ?? getSubGoals(forPatentId: goalId)
        )

        return progressMiniBar(percentage: snapshot.percentage)
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

    func createGoalsTracking(_ tracking: GoalsTracking) async -> GoalsTracking? {
        do{
            guard let savedTracking = try await manager.createGoalsTracking(tracking) else {
                return nil
            }
            upsertGoalTrackingInMemory(savedTracking)
            return savedTracking
        }
        catch{
            print("Failed to create goal tracking: \(error)")
            return nil
        }
    }

    func updateGoalsTracking(_ tracking: GoalsTracking) async -> GoalsTracking? {
        do {
            guard let savedTracking = try await manager.updateGoalsTracking(tracking) else {
                return nil
            }
            upsertGoalTrackingInMemory(savedTracking)
            return savedTracking
        }
        catch {
            print("Failed to update goal tracking: \(error)")
            return nil
        }
    }

    func deleteGoalsTrackingRecords(forTracking trackingId: Int64) async -> Bool {
        do {
            try await manager.deleteGoalsTrackingRecords(forTracking: trackingId)
            return true
        }
        catch {
            print("Failed to delete goal tracking records: \(error)")
            return false
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

    private func upsertGoalTrackingInMemory(_ tracking: GoalsTracking) {
        if let id = tracking.id,
           let index = goalTracking.firstIndex(where: { $0.id == id }) {
            goalTracking[index] = tracking
            return
        }

        if let index = goalTracking.firstIndex(where: { $0.goal_id == tracking.goal_id }) {
            goalTracking[index] = tracking
            return
        }

        goalTracking.append(tracking)
    }
}
