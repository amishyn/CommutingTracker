//
//  ActivityFlatiron.swift
//  CommutingTracker
//
//  Created by Alex Mishyn on 8/20/15.
//  Copyright (c) 2015 Alex Mishyn. All rights reserved.
//

import Foundation
import CoreMotion

class ActivityFlatiron {
    
    let keys = ["stationary", "walking", "running", "auto", "unknown", "cycling"]
    var minSegementDuration:Double = 1.5*60
    var debug = false
    var formatter: NSDateFormatter! = NSDateFormatter()

    func cleanData(activityList: [CMMotionActivity]) -> [CMMotionActivity] {
        return activityList.filter(valuableData)
    }
    
    func valuableData(activity: CMMotionActivity) -> Bool {
        var valuable = activity.stationary || activity.walking || activity.running || activity.automotive || activity.cycling
        
//        if (activity.confidence == CMMotionActivityConfidence.Low) {
//            valuable = false
//        }
//        
        return valuable
    }
    
    func sameActivity(a1: CMMotionActivity, a2: CMMotionActivity) -> Bool {
        return (a1.stationary == a2.stationary &&
        a1.walking    == a2.walking &&
        a1.running    == a2.running &&
        a1.automotive == a2.automotive &&
        a1.unknown    == a2.unknown &&
        a1.cycling    == a2.cycling)
    }

    func flatData(activityList: [CMMotionActivity]) -> [CMMotionActivity] {
        let flat = NSMutableArray()
        for(var i = 0; i < activityList.count; i++) {
            if (i == 0 || !sameActivity(activityList[i-1], a2: activityList[i])) {
                flat.addObject(activityList[i])
            }
        }
        return flat as NSArray as! [CMMotionActivity]
    }

    func mergeData(activityList: [CMMotionActivity]) -> [CMMotionActivity] {
        let merged = NSMutableArray()
        
        for(var i = 0; i < activityList.count; i++) {
            

            if (i > 1 && i < activityList.count - 2) {
                let duration = activityList[i+1].startDate.timeIntervalSinceDate(activityList[i].startDate)
//                println("duration: \(duration/60)")
                var merge = true
                let inBetweenCycling2 = (activityList[i-1].cycling) && (activityList[i+1].cycling)
                
                if (activityList[i].automotive && inBetweenCycling2 && duration < 7*60) {
//                    println("merge rejected 1: \(formatter.stringFromDate(activityList[i].startDate)),\(activityType(activityList[i]))")
                    merge = false
                }
                let unknown = !activityList[i].stationary && !activityList[i].walking && !activityList[i].running && !activityList[i].cycling && !activityList[i].automotive && !activityList[i].unknown
                
                if (unknown || (activityList[i].stationary || activityList[i].walking || activityList[i].running) && inBetweenCycling2 && duration < 5*60) {
//                    println("merge rejected 2: \(formatter.stringFromDate(activityList[i].startDate)),\(activityType(activityList[i])), \(duration) \(inBetweenCycling2)")
                    merge = false
                } else {
//                    println("merged: \(formatter.stringFromDate(activityList[i].startDate)),\(activityType(activityList[i])), \(duration) \(inBetweenCycling2)")
                }
                
                if (merge) {
                    merged.addObject(activityList[i])
                }
                
            } else {
                merged.addObject(activityList[i])
            }
        }
        return merged as NSArray as! [CMMotionActivity]
    }
    
    func extractSegments(activityList: [CMMotionActivity]) -> NSArray {
        let segments = NSMutableArray()
        var segment = NSMutableDictionary()
        for activity in activityList {
            if activity.cycling {
                segment["start_time_h"] = activity.startDate
            }
            else {
                if segment["start_time_h"] != nil {
                    segment["end_time_h"] = activity.startDate
                    let duration =  (segment["end_time_h"] as! NSDate).timeIntervalSinceDate((segment["start_time_h"] as! NSDate))
                    
                    if (duration > self.minSegementDuration) {
                        segments.addObject(segment)
                        segment = NSMutableDictionary()
                    } else {
                        // segment rejected
                        print("segment rejected, duration: \(duration) < min [\(self.minSegementDuration)]")
                        segment = NSMutableDictionary()
                    }
                }
            }
        }
        return segments as NSArray
    }
    func debugLog(activityList: [CMMotionActivity]) {
        if (!debug) {
            return
        }
        

        for activity in activityList {
            var confidence = 0
            if (activity.confidence == CMMotionActivityConfidence.High) {
                confidence += 100
            } else if (activity.confidence == CMMotionActivityConfidence.Medium) {
                confidence += 10
            } else if (activity.confidence == CMMotionActivityConfidence.Low) {
                confidence += 1
            }
            let typeString = String(format: "%-10s", (activityType(activity) as NSString).UTF8String)
            print("\(formatter.stringFromDate(activity.startDate)), \(typeString), \(confidence)")
        }
    }
    func activityType(activity: CMMotionActivity) -> String {
        var type = "unknown_default"
        
        if (activity.stationary){
                type = "stationary"
        } else if (activity.walking) {
            type = "walking"
        } else if (activity.running) {
            type = "running"
        } else if (activity.automotive) {
            type = "automotive"
        } else if (activity.unknown) {
            type = "unknown"
        } else if (activity.cycling) {
            type = "cycling"
        }

        return type
    }
    
    func processActivity(activityList: [CMMotionActivity]) -> NSArray {
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        print("Raw data")
        debugLog(activityList)

        
        let cleanedData = cleanData(activityList)
        print("cleanedData")
        debugLog(cleanedData)
        
        let flattedData = flatData(cleanedData)

        print("flattedData")
        debugLog(flattedData)

        let target1 = flatData(mergeData(flattedData))
        print("merged1 \(target1.count) ")
        debugLog(target1)
        print("---------------------------")

//        let target = target1
        let target = flatData(mergeData(target1))
        print("merged2 \(target.count)")
        debugLog(target)

        
        let segments = extractSegments(target)
        return segments
    }
}