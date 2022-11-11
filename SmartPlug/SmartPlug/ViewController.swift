//
//  ViewController.swift
//  SmartPlug
//
//  Created by Erdal on 9.05.2022.
//

import UIKit
import CoreBluetooth

let HMSoftUUID = CBUUID(string: "0xFFE0")  // CC2541-A default UUID  //service
let HMSoftCharacteristicCBUUID = CBUUID(string: "0xFFE1")


class ViewController: UIViewController {

    @IBOutlet weak var deviceTable: UITableView!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var buttonStartStop: UIButton!
    @IBOutlet weak var buttonDisconnect: UIButton!
    @IBOutlet weak var buttonOnOff: UIButton!
    @IBOutlet weak var buttonEditName: UIButton!
    
    var buttonImage:Int = 0
    var smartPlugStatus:Bool = false
    var searchStatus:Bool = true
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    var CBsozluk = [Any]()
    
    var RxData: String?
    var TxData: String?
    var BlueChart:CBCharacteristic?
    
    var findDeviceName = [String]()
    var signalLevel = [Any]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        deviceTable.delegate = self
        deviceTable.dataSource = self
        StatusUpdate(status: false)
        findDeviceName.removeAll(keepingCapacity: false)
        signalLevel.removeAll(keepingCapacity: false)
    }
    
    @IBAction func buttonStartStop(_ sender: Any) {
        if searchStatus == true {
           centralManager.stopScan()
           labelInfo.text = " Stopped scan "
           searchStatus = false
           buttonStartStop.setTitle("Start Scan", for: .normal)
        }else {
            StatusUpdate(status: false)
            findDeviceName.removeAll(keepingCapacity: false)
        }
    }
    
    @IBAction func buttonEditName(_ sender: Any) {
        print("Name Change Mode")    //sent signal to Arduino
        
        let alertController = UIAlertController(title: "Device Name Change", message: "Enter new name (max lenght is 12)", preferredStyle: .alert)
        alertController.addTextField {textfield in
            textfield.placeholder = "New Device Name"
            textfield.keyboardType = .default
            }
        let kaydetAction = UIAlertAction(title: "Kaydet", style:.destructive){ [self]
            action in
            let newName = (alertController.textFields![0] as UITextField).text!
            if (newName.count >= 13) || (newName.count == 0 ) {
                message(title: "Error", message: "New name is too long or empty")
            }else{
             print("Kaydet Tıklandı.")
             print("New Device Name : \(newName)")
             writeCharacteristic(TxData: "X\(newName)")
             message(title: "Name Changed", message: "New name : \(newName) ")
            }
            centralManager.cancelPeripheralConnection(peripheral)
            StatusUpdate(status: false)
        }
        alertController.addAction(kaydetAction)

        let iptalAction = UIAlertAction(title: "iptal", style:.cancel){
            action in
            print("İptal Tıklandı.")
        }
        alertController.addAction(iptalAction)
        self.present(alertController, animated: true)
    }
    
    @IBAction func buttonDisconnect(_ sender: Any) {
        print("disconnect button cliced")
        StatusUpdate(status: false)
        buttonStartStop.setTitle("Stop Scan", for: .normal)
        centralManager.cancelPeripheralConnection(peripheral)
        buttonImageChange(status: 2)
    }
    
    @IBAction func buttonOnOff(_ sender: UIButton) {
        if smartPlugStatus == true{
            smartPlugStatus = false
            buttonImageChange(status: 0)
            writeCharacteristic(TxData: "K")
            print("OFF")    //sent on signal to Arduino
        }else{
            smartPlugStatus = true
            buttonImageChange(status: 1)
            writeCharacteristic(TxData: "A")
            print("ON")    //sent on signal to Arduino
        }
    }
    
    func buttonImageChange ( status:Int){
        if status == 0 {
            buttonOnOff.setImage(UIImage(named: "off"), for: .normal)
        }
        if status == 1 {
            buttonOnOff.setImage(UIImage(named: "on"), for: .normal)
        }
        if status == 2 {
            buttonOnOff.setImage(UIImage(named: "idle"), for: .normal)
        }
    }
    
    func message (title:String , message:String){
        // create the alert
        let alert = UIAlertController(title: "\(title)", message: "\(message)", preferredStyle: UIAlertController.Style.alert)
        // add an action (button)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        // show the alert
        self.present(alert, animated: true, completion: nil)
        StatusUpdate(status: true)
    }
    
    func StatusUpdate ( status:Bool){
        if status == true{
            //connected to device
            labelInfo.text = "Connected"
            buttonDisconnect.isEnabled = true
            buttonEditName.isEnabled = true
            buttonStartStop.isEnabled = false
            deviceTable.isHidden = true
            buttonOnOff.isEnabled = true
        }else{
            // disconnect device
            labelInfo.text = "Scanning..."
            buttonDisconnect.isEnabled = false
            buttonEditName.isEnabled = false
            buttonStartStop.isEnabled = true
            buttonOnOff.isEnabled = false
            buttonImageChange(status: 2)
            //
            buttonStartStop.setTitle("Stop Scan", for: .normal)
            searchStatus = true
            findDeviceName.removeAll(keepingCapacity: false)
            signalLevel.removeAll(keepingCapacity: false)
            findDeviceName = []
            signalLevel = []
            
            startScan()
            deviceTable.isHidden = false
            //
        }
    }
}

// Tablo Tanımları
extension ViewController:UITableViewDelegate,UITableViewDataSource{
    // numberOfRowsInSection -> kaç tane row olacak   //return 5   //test satırı
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //return 5
        return findDeviceName.count
    }
    // cellForRow -> hücrenin içinde neler gösterilecek
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        //cell.textLabel?.text = "test"
        cell.textLabel?.text = "\(findDeviceName[indexPath.row]) , \(signalLevel[indexPath.row])"
        return cell
    }
    
    // didselect yazınca açılan listeden seçilir -  Tablodan bir seçim yapıldığında yapılacaklar
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        message(title: "Connected Device", message: "connected : \(findDeviceName[indexPath.row]) , \(signalLevel[indexPath.row])")
        labelInfo.text = "Connected : \(findDeviceName[indexPath.row])"
        centralManager.stopScan()
        peripheral = CBsozluk[indexPath.row] as? CBPeripheral
        peripheral.delegate = self
        centralManager.connect(peripheral)
        print("Connected!")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        //if peripheral == self.scale {}
        peripheral.discoverServices([HMSoftUUID])
    }
    //MARK: - Peripheral Delegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let service = peripheral.services?.first(where: {$0.uuid == HMSoftUUID }) {
            peripheral.discoverCharacteristics([HMSoftCharacteristicCBUUID], for: service)
            print("service found")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristic = service.characteristics?.first(where: {$0.uuid == HMSoftCharacteristicCBUUID }){
             peripheral.setNotifyValue(true, for: characteristic)
            BlueChart = characteristic
            print("characteristic found")
                let messageToSend = "D"  //ask to status
                peripheral.writeValue(messageToSend.data(using: .utf8)!, for: BlueChart!, type: .withoutResponse)
        }
    }
    //MARK: - Sent & Receive Data

    // Receive Data Functions
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            RxData = String(data: data, encoding: .utf8)
            print(RxData ?? "")
            if RxData == "1" {
                print("my status is ON")
                buttonOnOff.setImage(UIImage(named: "on"), for: .normal)
                smartPlugStatus = true
                
            }else if RxData == "0" {
                print("my status is OFF")
                buttonOnOff.setImage(UIImage(named: "off"), for: .normal)
                smartPlugStatus = false
            }
        }
    }
    // Write Data Functions
     func writeCharacteristic(TxData: String){
       let TxDataString = (TxData as NSString).data(using: String.Encoding.utf8.rawValue)
          //change the "data" to valueString
            peripheral.writeValue(TxDataString!, for: BlueChart!, type: .withoutResponse)
            print("sent : \(TxDataString!) : ")
     }
}

// Bluetooth Tanımları
extension ViewController:CBPeripheralDelegate, CBCentralManagerDelegate{
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScan()
        }
    }
    
    func startScan(){
        centralManager.scanForPeripherals(withServices: [HMSoftUUID], options: nil)
    }
    
    //Discovery
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        findDeviceName.append ("\(peripheral.name ?? "noname")")
        signalLevel.append("\(RSSI)")
        CBsozluk.append(peripheral)
        print("Discovered device : \(findDeviceName) , \(signalLevel)")
        labelInfo.text = ("Found Devices : \(findDeviceName.count)")
        deviceTable.reloadData()
    }
    
}
