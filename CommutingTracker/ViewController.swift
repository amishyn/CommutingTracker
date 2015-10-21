//
//  ViewController.swift
//  CommutingTracker
//
//  Created by Alex Mishyn on 7/28/15.
//  Copyright (c) 2015 Alex Mishyn. All rights reserved.
//

import UIKit
import CoreMotion

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate  {

    var coreMotionManager: CMMotionActivityManager?
    @IBOutlet weak var hoursFiled: UITextField!
    var formatter: NSDateFormatter! = NSDateFormatter()
    var dateFormatter: NSDateFormatter! = NSDateFormatter()
    var timeFormatter: NSDateFormatter! = NSDateFormatter()
    var activityStarted: Bool = false
    var defaults = NSUserDefaults.standardUserDefaults()
    var segments = NSMutableArray()
    
    @IBOutlet weak var debug: UISwitch!
    @IBOutlet weak var textLog: UILabel!
    @IBOutlet weak var activityConrol: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var minDurationTextField: UITextField!

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var totalTimeValueLabel: UILabel!
    @IBOutlet weak var segmentsCountValueLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        coreMotionManager = CMMotionActivityManager()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        timeFormatter.dateFormat = "HH:mm"
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func updateTotals() {
        var totalDuration = 0.0
        for segment in self.segments {
            let duration = (segment["end_time_h"] as! NSDate).timeIntervalSinceDate((segment["start_time_h"] as! NSDate))
            totalDuration += duration
        }
        let formattedDuration = String(format: "%.2f", totalDuration/60)
        self.totalTimeValueLabel.text = "\(formattedDuration) min"
        
        self.segmentsCountValueLabel.text = String(self.segments.count)
    }
    @IBAction func fetchActivityTapped(sender: AnyObject) {
        self.hoursFiled.resignFirstResponder()
        self.minDurationTextField.resignFirstResponder()
        self.textLog.text = ""
        self.activityIndicator.startAnimating()
        let calendar = NSCalendar.currentCalendar()
        let backHours = Int(hoursFiled.text!)
        let startDate:NSDate = calendar.dateByAddingUnit([.Hour], value: -1*backHours!, toDate: NSDate(), options: NSCalendarOptions())!
        let endDate:NSDate = NSDate()

        
        coreMotionManager?.queryActivityStartingFromDate(startDate, toDate: endDate, toQueue: NSOperationQueue(), withHandler: { (activities: [CMMotionActivity]?, error: NSError?) -> Void in
            if (activities != nil) {
                let af = ActivityFlatiron()
                af.debug = self.debug.on
                af.minSegementDuration = Double(self.minDurationTextField.text!)!
                self.segments = af.processActivity(activities!) as! NSMutableArray
                self.segments = NSMutableArray(array: self.segments.reverse())
                dispatch_async(dispatch_get_main_queue(), {
                    self.tableView.reloadData()
                    self.updateTotals()
                    self.activityIndicator.stopAnimating()
                })
                
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    self.logToDisplay("No activity")
                })
            }
            
        })
        
        
    }
    
    @IBAction func activityControlTapped(sender: AnyObject) {
        
        let log = NSMutableArray()
        let existingLog = defaults.arrayForKey("activityLog")
        if (existingLog != nil) {
            log.addObjectsFromArray(existingLog!)
        }
        
        if (activityStarted == true) {
            self.activityConrol.setTitle("Start activity", forState: UIControlState.Normal)
            activityStarted = false
            log.addObject(["stopped", NSDate()])
        }
        else {
            activityStarted = true
            self.activityConrol.setTitle("Stop activity", forState: UIControlState.Normal)
            log.addObject(["started", NSDate()])
        }
        
        
        defaults.setObject(log, forKey: "activityLog")
        
    }
    
    /* pragma Logic*/
    
    func printActivityProps(activity: CMMotionActivity) {
        var confidence = 0
        if (activity.confidence == CMMotionActivityConfidence.High) {
            confidence += 100
        } else if (activity.confidence == CMMotionActivityConfidence.Medium) {
            confidence += 10
        } else if (activity.confidence == CMMotionActivityConfidence.Low) {
            confidence += 1
        }

        
        logToDisplay("\(activity.startDate.timeIntervalSince1970), \(formatter.stringFromDate(activity.startDate)),\(activity.stationary),\(activity.walking),\(activity.running),\(activity.automotive),\(activity.unknown),\(activity.cycling),\(confidence)")
       
    }

    func logToDisplay (text:NSString) {
        self.textLog.text = "\(self.textLog.text! as String) \n\(text as String)"
        print("\(text)")
    }
    
    func leftSon(step: Int, activities: [AnyObject]) -> Bool {
        return  step > 0  && activities[step].cycling == true
    }
    
    func rightSon(step: Int, activities: [AnyObject]) -> Bool {
        return step < activities.count && activities[step].cycling == true
    }
    
    func filterCycling(activities: [AnyObject]!) -> [AnyObject]! {
        var filteredActivities = NSMutableArray()
        for(var i = 0; i < activities.count; i++) {

            var testedPoint = activities[i] as! CMMotionActivity

            var surrounding = leftSon(i-1, activities: activities) || leftSon(i-2, activities: activities) || rightSon(i+1, activities: activities) || rightSon(i+2, activities: activities)
            if ( testedPoint.cycling == true && surrounding) {
                filteredActivities.addObject(testedPoint)
            }
        }

        return filteredActivities as [AnyObject]
    }
    // todo split into intervals
    // and show thei duration
    func findInterval(activities: [AnyObject]!) {
        if activities.count < 2 {
            return
        }
        logToDisplay("Interval: \(formatter.stringFromDate(activities.first!.startDate!)), \(formatter.stringFromDate(activities.last!.startDate!))")
    }
    // table
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.segments.count
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, canPerformAction action: Selector, forRowAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) -> Bool {
        return true
    }
    //    http://www.raywenderlich.com/62435/make-swipeable-table-view-cell-actions-without-going-nuts-scroll-views
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            self.segments.removeObjectAtIndex(indexPath.row)
            self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
        } else {
            print("Unhandled editing style! %d", editingStyle);
        }
        self.updateTotals()
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let segment = self.segments[indexPath.row]
        let cell = tableView.dequeueReusableCellWithIdentifier("segmentCell") as UITableViewCell!

        let duration = (segment["end_time_h"] as! NSDate).timeIntervalSinceDate((segment["start_time_h"] as! NSDate))
        let formattedDuration = String(format: "%.2f", duration/60)
        let st = segment["start_time_h"] as! NSDate
        let et = segment["end_time_h"] as! NSDate
        
        
        cell!.textLabel?.text = "\(self.timeFormatter.stringFromDate(st)) - \(self.timeFormatter.stringFromDate(et)) - \(formattedDuration) - \(self.dateFormatter.stringFromDate(st))"
        cell!.selectionStyle = UITableViewCellSelectionStyle.None
        return cell!
    }
    
    
}

