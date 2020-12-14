//
//  InterfaceController.swift
//  watchOS-heartrate WatchKit Extension
//
//  Created by yorifuji on 2020/05/08.
//  Copyright © 2020 yorifuji. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit
import FirebaseStorage

var currentHapticType: WKHapticType = WKHapticType.directionUp

class InterfaceController: WKInterfaceController {

    @IBOutlet weak var label: WKInterfaceLabel!
    @IBOutlet var imageView: WKInterfaceImage!
    @IBOutlet weak var button: WKInterfaceButton!

    let fontSize = UIFont.systemFont(ofSize: 50)

    let healthStore = HKHealthStore()
    let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let heartRateUnit = HKUnit(from: "count/min")
    var heartRateQuery: HKQuery?

    var workoutSession: HKWorkoutSession?
    
    var heartRate: Int = 60
    var timeVal = 0.0
        
    @objc func playHaptic() -> Void {
        WKInterfaceDevice.current().play(currentHapticType)
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        // Configure interface objects here.
        print(#function)

        guard HKHealthStore.isHealthDataAvailable() else {
            label.setText("HealthKit is not available on this device.")
            print("HealthKit is not available on this device.")
            return
        }

        let dataTypes = Set([heartRateType])
        self.healthStore.requestAuthorization(toShare: nil, read: dataTypes) { (success, error) in
            guard success else {
                self.label.setText("Requests permission is not allowed.")
                print("Requests permission is not allowed.")
                return
            }
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        print(#function)
//        let storage = Storage.storage()
//        let storageRef = storage.reference(forURL: "gs://heart-rate-68931.appspot.com/").child("sparky.png")
//        storageRef.getData(maxSize: 1024 * 1024) { data, error  in
//            self.imageView.setImageData(data)
//        }
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        print(#function)
    }

    @IBAction func btnTapped() {
        print(#function)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {_ in
            self.timeVal += 0.1
            let rate = 60.0 / Double(self.heartRate)
            print(self.heartRate, rate, self.timeVal)
            if self.timeVal >= rate {
                self.timeVal = 0.0
                self.playHaptic()
            }
        }
        if self.workoutSession == nil {
            let config = HKWorkoutConfiguration()
            config.activityType = .other
            do {
                self.workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
                self.workoutSession?.delegate = self
                self.workoutSession?.startActivity(with: nil)
            }
            catch let e {
                print(e)
            }
        }
        else {
            self.workoutSession?.stopActivity(with: nil)
        }
    }
}

extension InterfaceController {

    private func createStreamingQuery() -> HKQuery {
        print(#function)
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: [])
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { (query, samples, deletedObjects, anchor, error) in
            self.addSamples(samples: samples)
        }
        query.updateHandler = { (query, samples, deletedObjects, anchor, error) in
            self.addSamples(samples: samples)
        }
        return query
    }

    private func addSamples(samples: [HKSample]?) {
        print(#function)
        guard let samples = samples as? [HKQuantitySample] else { return }
        guard let quantity = samples.last?.quantity else { return }
        print(quantity)
        heartRate = Int(quantity.doubleValue(for: heartRateUnit))
        print(Int(quantity.doubleValue(for: heartRateUnit)))
        
        var jsonDict: Dictionary<String, Any>?
        var jsonStr: String?
        var heartRate: Array<Int>?
        
        let storage = Storage.storage()
        let storageRef = storage.reference(forURL: "gs://heart-rate-68931.appspot.com").child("data/heartRate.json")
        storageRef.getData(maxSize: 1024 * 1024) { data, error in
        
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments)
                jsonDict = json as! Dictionary<String, Any>
               
                heartRate = jsonDict?["heartRate"] as! Array<Int>
                
                heartRate?.append(Int(quantity.doubleValue(for: self.heartRateUnit)))
                jsonDict?.updateValue(heartRate, forKey: "heartRate")

                jsonStr = """
{"heartRate": \(heartRate! as Array<Int>)}
"""
                
                let storageRef2 = storage.reference(forURL: "gs://heart-rate-68931.appspot.com").child("data/heartRate.json")

                // Create file metadata including the content type
                let metadata = StorageMetadata()
                metadata.contentType = "application/json"
                
                let uploadTask = storageRef2.putData((jsonStr?.data(using: .utf8))!, metadata: metadata) { metadata, error in
                    guard metadata != nil else {
                    // Uh-oh, an error occurred!
                    print(error)
                    return
                  }
                }
            } catch {
                print(error)
            }
        }

        let text = String(quantity.doubleValue(for: self.heartRateUnit))
        let attrStr = NSAttributedString(string: text, attributes:[NSAttributedString.Key.font:self.fontSize])
        DispatchQueue.main.async {
            self.label.setAttributedText(attrStr)
        }
    }
}

extension InterfaceController: HKWorkoutSessionDelegate {

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        
        print(#function)
        switch toState {
        case .running:
            print("Session status to running")
            self.startQuery()
        case .stopped:
            print("Session status to stopped")
            self.stopQuery()
            self.workoutSession?.end()
        case .ended:
            print("Session status to ended")
            self.workoutSession = nil
        default:
            print("Other status \(toState.rawValue)")
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("workoutSession delegate didFailWithError \(error.localizedDescription)")
    }

    func startQuery() {
        print(#function)
        heartRateQuery = self.createStreamingQuery()
        healthStore.execute(self.heartRateQuery!)
        DispatchQueue.main.async {
            self.button.setTitle("計測終了")
        }
    }

    func stopQuery() {
        print(#function)
        healthStore.stop(self.heartRateQuery!)
        heartRateQuery = nil
        DispatchQueue.main.async {   
            self.button.setTitle("計測開始")
            self.label.setText("")
        }
    }
}
