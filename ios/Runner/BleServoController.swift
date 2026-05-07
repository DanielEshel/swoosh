import Foundation
import CoreBluetooth
import Flutter

class BleServoController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, BleCommandApi {
    
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var servoCharacteristic: CBCharacteristic?
    
    private let stateApi: BleStateApi
    private var isPendingScan = false
    
    let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-1234567890ab")
    let characteristicUUID = CBUUID(string: "12345678-1234-1234-1234-1234567890ac")
    let sensorCharacteristicUUID = CBUUID(string: "12345678-1234-1234-1234-1234567890ad")

    init(binaryMessenger: FlutterBinaryMessenger) {
        self.stateApi = BleStateApi(binaryMessenger: binaryMessenger)
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func scanForDevices() throws {
        discoveredPeripherals.removeAll()
        if centralManager.state == .poweredOn {
            startActualScan()
        } else {
            isPendingScan = true
        }
    }
    
    private func startActualScan() {
        DispatchQueue.main.async {
            self.stateApi.onConnectionStateChanged(state: "scanning") { _ in }
        }
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    
    func connectToDevice(deviceId: String) throws {
        guard let peripheral = discoveredPeripherals[deviceId] else { return }
        centralManager.stopScan()
        connectedPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnectDevice() throws {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if isPendingScan {
                isPendingScan = false
                startActualScan()
            }
        } else {
            DispatchQueue.main.async {
                self.stateApi.onConnectionStateChanged(state: "disconnected") { _ in }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceId = peripheral.identifier.uuidString
        discoveredPeripherals[deviceId] = peripheral
        let name = peripheral.name ?? "Swoosh Tracker"
        
        DispatchQueue.main.async {
            self.stateApi.onDeviceDiscovered(id: deviceId, name: name) { _ in }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.stateApi.onConnectionStateChanged(state: "connected") { _ in }
        }
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.stateApi.onConnectionStateChanged(state: "disconnected") { _ in }
        }
        self.servoCharacteristic = nil
        self.connectedPeripheral = nil
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID, sensorCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                self.servoCharacteristic = characteristic
                print("🔵 Swift BLE: Servo characteristic found and ready!")
            }
            
            if characteristic.uuid == sensorCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                print("🟢 Swift BLE: Subscribed to Sensor updates!")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == sensorCharacteristicUUID, let data = characteristic.value {
            if let distanceString = String(data: data, encoding: .utf8) {
                print("Sensor Distance: \(distanceString) cm")
                DispatchQueue.main.async {
                    // This sends the data to Flutter via the method you added to Pigeon
                    self.stateApi.onSensorDataReceived(data: distanceString) { _ in }
                }
            }
        }
    }
    
    // MARK: - Flutter API Writer
    
    func sendServoCommand(command: String) {
        guard let peripheral = connectedPeripheral, let characteristic = servoCharacteristic else { return }
        guard let data = command.data(using: .utf8) else { return }
        
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: characteristic, type: writeType)
    }
}