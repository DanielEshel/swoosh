//
//  BleServoController.swift
//  Runner
//
//  Created by Daniel Eshel on 14/04/2026.
//

import Foundation
import CoreBluetooth
import Flutter

class BleServoController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, BleCommandApi {
    
    private var centralManager: CBCentralManager!
    private var esp32Peripheral: CBPeripheral?
    private var servoCharacteristic: CBCharacteristic?
    
    private let stateApi: BleStateApi
    
    // IMPORTANT: Replace these with the actual UUIDs programmed into your ESP32
    let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    let characteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    
    init(binaryMessenger: FlutterBinaryMessenger) {
        // Initialize the Flutter to Swift communication channel
        self.stateApi = BleStateApi(binaryMessenger: binaryMessenger)
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - BleCommandApi (Triggered by Flutter UI)
    func scanForDevices() throws {
        if centralManager.state == .poweredOn {
            stateApi.onConnectionStateChanged(state: "scanning") { _ in }
            // Only scan for devices broadcasting your specific ESP32 service
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }
    
    func connectToDevice(deviceId: String) throws {
        guard let peripheral = esp32Peripheral else { return }
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnectDevice() throws {
        if let peripheral = esp32Peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    // MARK: - CoreBluetooth Callbacks
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            stateApi.onConnectionStateChanged(state: "disconnected") { _ in }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.esp32Peripheral = peripheral
        let name = peripheral.name ?? "Swoosh Tracker"
        
        // Notify Flutter we found it
        stateApi.onDeviceDiscovered(id: peripheral.identifier.uuidString, name: name) { _ in }
        
        // Automatically stop scanning to save battery
        centralManager.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stateApi.onConnectionStateChanged(state: "connected") { _ in }
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
         stateApi.onConnectionStateChanged(state: "disconnected") { _ in }
         self.servoCharacteristic = nil
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                self.servoCharacteristic = characteristic
            }
        }
    }
    
    // MARK: - The "Tight Loop" Hardware Writer
    func sendServoCommand(angle: Int) {
        guard let peripheral = esp32Peripheral, let characteristic = servoCharacteristic else { return }
        
        // Assuming your ESP32 expects a single byte value (0 to 180 degrees)
        let clampedAngle = UInt8(max(0, min(180, angle)))
        let data = Data([clampedAngle])
        
        // .withoutResponse is CRITICAL for zero-latency streaming
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }
}
