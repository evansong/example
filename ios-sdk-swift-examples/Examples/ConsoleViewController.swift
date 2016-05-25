//
//  ConsoleViewController.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//  Console Print Example
//

import UIKit
import IndoorAtlas
import SVProgressHUD

// View controller for Console Print Example
class ConsoleViewController: UIViewController, IALocationManagerDelegate, RKResponseObserver {
    var robot: RKConvenienceRobot!
    var calibrateHandler: RUICalibrateGestureHandler!
    var ledON = false
    var VELOCITY: Float = 0.2
    var move = false
    
    @IBOutlet weak var lblOutput: UILabel!
    @IBOutlet weak var connectionLabel: UILabel!
    @IBOutlet weak var moveStatus: UILabel!
    @IBOutlet weak var lblPosition: UILabel!
    
    
    @IBAction func MoveForward(sender: AnyObject) {
        self.robot.driveWithHeading(0.0, andVelocity: 0);
        self.robot.setZeroHeading();
        
        //self.robot.sendCommand(RKRollCommand(heading: 0.0, andVelocity: VELOCITY));
        //self.robot.sendCommand(RKRollCommand(heading: 0.0, velocity: VELOCITY, andDistance: 30.0));
        move = true;
        moveStatus.text = "Moving forward";
    }
    
    func handleAsyncMessage(message: RKAsyncMessage!, forRobot robot: RKRobotBase!) {
        if let sensorMessage = message as? RKDeviceSensorsAsyncData {
            let sensorData = sensorMessage.dataFrames.last as? RKDeviceSensorsData;
            
            if let sensorDataValue = sensorData {
                
                let acceleration = sensorDataValue.accelerometerData.acceleration;
                let attitude = sensorDataValue.attitudeData;
                let gyro = sensorDataValue.gyroData;
                let locator = sensorDataValue.locatorData;
                
                let accelX = acceleration.x;
                let accelY = acceleration.y;
                let accelZ = acceleration.z;
                
                let roll = attitude.roll;
                let yaw = attitude.yaw;
                let pitch = attitude.pitch;
                
                let gyroX = gyro.rotationRate.x;
                let gyroY = gyro.rotationRate.y;
                let gyroZ = gyro.rotationRate.z;
                
                let locatorPositionX = locator.position.x;
                let locatorPositionY = locator.position.y;
                let locatorVelocityX = locator.velocity.x;
                let locatorVelocityY = locator.velocity.y;
                
                if (locatorPositionY > 100)
                {
                    self.robot.stop();
                    moveStatus.text = "Stopping";
                    move = false
                }
                else
                {
                    self.robot.sendCommand(RKRollCommand(heading: 0.0, andVelocity: VELOCITY));
                }
                lblPosition.text = "X \(locatorPositionX), Y \(locatorPositionY)"
            }
        }
    }
    
    // Manager for IALocationManager
    var manager = IALocationManager()
    
    // Bool for checking if the HUD has been already changed to "Printing to console"
    var HUDstatusChanged = false
    
    override func viewDidLoad() {
        
        self.calibrateHandler = RUICalibrateGestureHandler(view: self.view);
        
        super.viewDidLoad()
        
        startDiscovery()
        
        RKRobotDiscoveryAgent.sharedAgent().addNotificationObserver(self, selector: #selector(ConsoleViewController.handleRobotStateChangeNotification(_:)))

        // Show spinner while waiting for location information from IALocationManager
        SVProgressHUD.showWithStatus(NSLocalizedString("Waiting for location", comment: ""))
    }
    
    override func viewDidDisappear(animated: Bool) {
        RKRobotDiscoveryAgent.disconnectAll()
        stopDiscovery()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        connectionLabel = nil;
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)
    }
    
    func handleRobotStateChangeNotification(notification: RKRobotChangedStateNotification) {
        let noteRobot = notification.robot
        
        switch (notification.type) {
        case .Connecting:
            connectionLabel.text = "\(notification.robot.name()) Connecting"
            break
            
        case .Online:
            let conveniencerobot = RKConvenienceRobot(robot: noteRobot);
            
            if (UIApplication.sharedApplication().applicationState != .Active) {
                conveniencerobot.disconnect()
            } else {
                self.robot = RKConvenienceRobot(robot: noteRobot);
                
                
                self.robot.addResponseObserver(self);
                self.robot.enableLocator(true);
                
                //Create a mask for the sensors you are interested in
                let mask: RKDataStreamingMask = [.AccelerometerFilteredAll, .IMUAnglesFilteredAll, .GyroFilteredAll, .LocatorAll];
                self.robot.enableSensors(mask, atStreamingRate: RKStreamingRate.DataStreamingRate1);
                
                connectionLabel.text = noteRobot.name()
                togleLED()
            }
            
            connectionLabel.text = "Connected"
            break
            
        case .Disconnected:
            connectionLabel.text = "Disconnected"
            self.robot = RKConvenienceRobot(robot: noteRobot);
            self.robot.removeResponseObserver(self)
            //startDiscovery()
            calibrateHandler.robot = nil;
            robot = nil;
            break
            
        default:
            NSLog("State change with state: \(notification.type)")
        }
    }
    
    func startDiscovery() {
        connectionLabel.text = "Discovering Robots"
        RKRobotDiscoveryAgent.startDiscovery()
    }

    func stopDiscovery() {
        RKRobotDiscoveryAgent.stopDiscovery()
    }
    
    func blink(lit: Bool) {
        if (lit) {
            robot.sendCommand(RKRGBLEDOutputCommand(red: 0.0, green: 0.0, blue: 0.0))
        } else {
            robot.sendCommand(RKRGBLEDOutputCommand(red: 1.0, green: 0.0, blue: 0.0))
        }
        
        let delay = Int64(0.5 * Float(NSEC_PER_SEC))
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), { () -> Void in
            self.blink(!lit);
        })
    }
    
    func togleLED() {
        if let robot = self.robot {
            if (ledON) {
                robot.setLEDWithRed(0.0, green: 0.0, blue: 0.0)
            } else {
                robot.setLEDWithRed(0.0, green: 0.0, blue: 1.0)
            }
            ledON = !ledON
            
            let delay = Int64(0.5 * Float(NSEC_PER_SEC))
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), { () -> Void in
                self.togleLED();
            })
        }
    }
    
    // Hide status bar
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    // This function is called whenever new location is received from IALocationManager
    func indoorLocationManager(manager: IALocationManager, didUpdateLocations locations: [AnyObject]) {
        // Check if the HUD status is already changed to "Printing to console" if not, change it
        if !HUDstatusChanged {
            SVProgressHUD.showWithStatus(NSLocalizedString("Printing to console", comment: ""))
            HUDstatusChanged = true
        }
        
        // Convert last location to IALocation
        let l = locations.last as! IALocation
        
        // The accuracy of coordinate position depends on the placement of floor plan image.
        lblOutput.text = "(lat, lon): \((l.location?.coordinate.latitude)!), \((l.location?.coordinate.longitude)!)"
        print("Position changed to coordinate (lat,lon): ", (l.location?.coordinate.latitude)!, (l.location?.coordinate.longitude)!)

    }
    
    // Authenticate to IndoorAtlas services and request location updates
    func requestLocation() {
        
        // Point delegate to receiver
        manager.delegate = self
        
        // Optionally, initial location
        let location: IALocation = IALocation(floorPlanId: kFloorplanId)
        manager.location = location
        
        // Request location updates
        manager.startUpdatingLocation()
    }
    
    // When view appears start requesting location updates
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        UIApplication.sharedApplication().statusBarHidden = true

        requestLocation()
    }
    
    // When view disappears dismiss SVProgressHUD and stop updating the location
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(true)
        
        manager.stopUpdatingLocation()
        manager.delegate = nil
        
        UIApplication.sharedApplication().statusBarHidden = false
        
        SVProgressHUD.dismiss()
    }
}

