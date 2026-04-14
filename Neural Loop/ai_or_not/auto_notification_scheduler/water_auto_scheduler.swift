//
//  water.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 21/01/2026.
//
import SwiftUI

@MainActor
final class WaterAutoScheduling {
    
    static let shared = WaterAutoScheduling()
    
    final let habit_id: Int64 = 1
    
    var schedule: [Date] = []
    
    init(){
        Task {
            await scheduleMorningRepeatWaterAuto()
        }
    }
    
    func scheduleMorningRepeatWaterAuto(hour: Int = 6, minute: Int = 0) async {
        let id = "repeat_water_auto"
        

        // Remove existing (recreate if it exists)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])

        // Build repeating date components (daily at hour:minute)
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute

        await NotificationManager.shared.scheduleRepeatingNotification(
            id: id,
            title: "Drink Water 💧",
            body: "Start your day with a glass of water",
            dateComponents: comps,
            sound: .default
        )

        print("🟢 [WaterAutoScheduling] Scheduled daily repeating morning reminder at \(hour):\(String(format: "%02d", minute))")
    }
    
    func get_calendar_data() -> [String: [Date]]{
        return ["Water": schedule]
    }
    
    
    func schedule_notification(current: Int, target: Int) async {

        let requested = max(target - current, 0)
        let prefix = "water_auto_"
        schedule = []

        await NotificationManager.shared.clearIndexedNotificationsAsync(prefix: prefix)

        guard requested > 0 else {
            print("🟡 [WaterAutoScheduling] No remaining water reminders needed")
            return
        }

        let calendar = Calendar.current
        let now = Date()

        // ---- Config ----
        let minGap: TimeInterval = 20 * 60 // 20 minutes
        let cutoffHour = 22 // 10 PM

        // Today's 10 PM cutoff
        var endComponents = calendar.dateComponents([.year, .month, .day], from: now)
        endComponents.hour = cutoffHour
        endComponents.minute = 0

        guard let endTime = calendar.date(from: endComponents),
              endTime > now else {
            
            print("🔴 [WaterAutoScheduling] Invalid end time for scheduling ")
            return
        }

        // If we must keep minGap, compute max possible reminders
        let totalAvailable = endTime.timeIntervalSince(now)
        let maxPossible = Int(floor(totalAvailable / minGap)) // first one can be at now+minGap
        let remaining = min(requested, maxPossible)

        if remaining <= 0 {
            print("🟡 [WaterAutoScheduling] Not enough time left today for min-gap reminders")
            return
        }

        if remaining < requested {
            print("🟠 [WaterAutoScheduling] Requested \(requested) but can only schedule \(remaining) due to 20min gap")
        }

        // ---- Meal anchors (try to schedule before these) ----
        // We schedule them 10 minutes before the meal time (still "before lunch/dinner")
        func todayAt(_ hour: Int, _ minute: Int) -> Date? {
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = hour
            comps.minute = minute
            return calendar.date(from: comps)
        }

        guard let lunchTime = todayAt(13, 0),
              let dinnerTime = todayAt(21, 0) else {
            print("🔴 [WaterAutoScheduling] Could not build meal times")
            return
        }

        let lunchAnchor = lunchTime.addingTimeInterval(-10 * 60)   // 12:50
        let dinnerAnchor = dinnerTime.addingTimeInterval(-10 * 60) // 20:50

        func isValidAnchor(_ d: Date) -> Bool {
            // must be after now + minGap and before cutoff
            return d > now.addingTimeInterval(minGap) && d < endTime
        }

        var anchors: [Date] = []
        if remaining >= 1, now < lunchTime, isValidAnchor(lunchAnchor) {
            anchors.append(lunchAnchor)
        }
        if remaining >= 2, now < dinnerTime, isValidAnchor(dinnerAnchor) {
            anchors.append(dinnerAnchor)
        }

        // If we have only 1 slot, prefer lunch if possible (already handled above)
        if remaining == 1, anchors.count > 1 {
            anchors = [anchors[0]]
        }

        // ---- Build segments around anchors ----
        // We will fill the rest evenly in each segment.
        // Segment endpoints are:
        // start -> anchor1 -> anchor2 -> end
        let sortedAnchors = anchors.sorted()
        let points: [Date] = [now] + sortedAnchors + [endTime]

        // How many reminders left after anchors?
        var fillCount = remaining - sortedAnchors.count

        // Allocate fillCount across segments proportionally by duration,
        // but also cap by how many can fit with minGap.
        var segmentCounts: [Int] = []
        var segmentDurations: [TimeInterval] = []

        for i in 0..<(points.count - 1) {
            let a = points[i]
            let b = points[i + 1]
            let dur = max(b.timeIntervalSince(a), 0)
            segmentDurations.append(dur)
        }

        let totalDur = segmentDurations.reduce(0, +)

        for dur in segmentDurations {
            if fillCount == 0 || totalDur <= 0 {
                segmentCounts.append(0)
                continue
            }

            // proportional share
            let raw = Double(fillCount) * (dur / totalDur)
            segmentCounts.append(Int(round(raw)))
        }

        // Fix rounding issues to ensure sum == fillCount
        func fixSumToTarget(_ arr: inout [Int], target: Int) {
            var sum = arr.reduce(0, +)
            while sum > target {
                if let idx = arr.indices.max(by: { arr[$0] < arr[$1] }), arr[idx] > 0 {
                    arr[idx] -= 1
                    sum -= 1
                } else { break }
            }
            while sum < target {
                if let idx = arr.indices.max(by: { segmentDurations[$0] < segmentDurations[$1] }) {
                    arr[idx] += 1
                    sum += 1
                } else { break }
            }
        }

        fixSumToTarget(&segmentCounts, target: fillCount)

        // Cap each segment by minGap capacity
        for i in segmentCounts.indices {
            let dur = segmentDurations[i]
            let maxInSegment = Int(floor(dur / minGap))
            segmentCounts[i] = min(segmentCounts[i], maxInSegment)
        }

        // If capping reduced total, we accept fewer fills (still respects minGap)
        let cappedFillTotal = segmentCounts.reduce(0, +)
        if cappedFillTotal < fillCount {
            print("🟠 [WaterAutoScheduling] Reduced filler reminders from \(fillCount) -> \(cappedFillTotal) (segment minGap limits)")
            fillCount = cappedFillTotal
        }

        // ---- Generate times ----
        var times: [Date] = []
        times.append(contentsOf: sortedAnchors)

        for i in 0..<(points.count - 1) {
            let start = points[i]
            let end = points[i + 1]
            let count = segmentCounts[i]
            guard count > 0 else { continue }

            let dur = end.timeIntervalSince(start)
            guard dur > 0 else { continue }

            // Even spacing inside the segment (not touching endpoints)
            for k in 0..<count {
                let t = start.addingTimeInterval(dur * (Double(k + 1) / Double(count + 1)))
                times.append(t)
            }
        }

        times.sort()

        // ---- Enforce minGap globally by DROPPING offenders (anchors stay put) ----
        var finalTimes: [Date] = []
        for t in times {
            if finalTimes.isEmpty {
                // must be at least now+minGap
                if t > now.addingTimeInterval(minGap) {
                    finalTimes.append(t)
                }
            } else {
                if t.timeIntervalSince(finalTimes.last!) >= minGap {
                    finalTimes.append(t)
                }
            }
            if finalTimes.count == remaining { break }
        }

        if finalTimes.isEmpty {
            print("🟡 [WaterAutoScheduling] No valid reminder times after applying minGap")
            return
        }

        // ---- Schedule ----
        
        for (index, fireDate) in finalTimes.enumerated() {
            let id = prefix + "\(index)"
            schedule.append(fireDate)
            await NotificationManager.shared.scheduleNotification(
                id: id,
                title: "Drink Water 💧",
                body: "Time to drink a glass of water",
                date: fireDate,
                userInfo: ["habit_id": habit_id]
            )
        }

        print("🟢 [WaterAutoScheduling] Scheduled \(finalTimes.count) water reminders (requested \(requested))")
    }
    
}
