import Foundation
import CoreBluetooth
import UIKit

class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()

    // MARK: - UUIDs Conhecidos do Galaxy Fit3
    let serviceHeartRate = CBUUID(string: "180D")
    let charHeartRateMeasurement = CBUUID(string: "2A37")
    let charSensorLocation = CBUUID(string: "2A38")

    let serviceDeviceInfo = CBUUID(string: "180A")
    let charModel = CBUUID(string: "2A24")
    let charFirmware = CBUUID(string: "2A26")

    let serviceBattery = CBUUID(string: "180F")
    let charBatteryLevel = CBUUID(string: "2A19")

    // Canal proprietário bidirecional da Samsung
    let serviceSamsungData = CBUUID(string: "1B7E8251-2877-41C3-B46E-CF057C562023")
    let charSamsungComm = CBUUID(string: "8AC32D3F-5CB9-4D44-BEC2-EE689169F626")

    // MARK: - Estados Publicados para a Interface SwiftUI
    private var centralManager: CBCentralManager!
    @Published var connectedPeripheral: CBPeripheral?
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var connectionStatus = "Desconectado"

    @Published var heartRate: Int = 0
    @Published var watchBattery: Int = 0
    @Published var iPhoneBattery: Int = 0
    @Published var firmwareVersion: String = "--"
    @Published var logs: [String] = []

    private var commCharacteristic: CBCharacteristic?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        setupBatteryMonitoring()
    }

    func addLog(_ msg: String) {
        DispatchQueue.main.async {
            let time = Date().formatted(date: .omitted, time: .standard)
            self.logs.append("[\(time)] \(msg)")
            if self.logs.count > 50 { self.logs.removeFirst() }
        }
    }

    // MARK: - Controle de Conexão
    func startScan() {
        guard centralManager.state == .poweredOn else {
            addLog("Bluetooth desligado ou sem permissão.")
            return
        }
        isScanning = true
        connectionStatus = "Buscando Galaxy Fit3..."
        addLog("Iniciando varredura BLE...")
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    func disconnect() {
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
    }

    // MARK: - Monitoramento da Bateria do iPhone
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updatePhoneBattery()
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updatePhoneBattery()
        }
    }

    func updatePhoneBattery() {
        let level = Int(UIDevice.current.batteryLevel * 100)
        self.iPhoneBattery = max(0, level)
    }

    // MARK: - Envio de Notificações Customizadas para o Fit3
    func sendNotificationToWatch(title: String, body: String) {
        guard let p = connectedPeripheral, let char = commCharacteristic else {
            addLog("Canal de comunicação não disponível para envio.")
            return
        }

        // Monta o payload de notificação no formato TLV / Samsung Accessory
        var packet = Data([0x01, 0x10]) // Cabeçalho do pacote de notificação
        let titleData = title.data(using: .utf8) ?? Data()
        let bodyData = body.data(using: .utf8) ?? Data()

        packet.append(UInt8(titleData.count))
        packet.append(titleData)
        packet.append(UInt8(bodyData.count))
        packet.append(bodyData)

        p.writeValue(packet, for: char, type: .withResponse)
        addLog("Notificação enviada: \(title)")
    }

    // MARK: - Comando para Troca de Idioma (PT-BR)
    func sendLanguageSync(locale: String = "pt_BR") {
        guard let p = connectedPeripheral, let char = commCharacteristic else { return }
        
        // Pacote de comando de configuração de idioma
        var packet = Data([0x02, 0x05]) // Comando de idioma
        if let locData = locale.data(using: .utf8) {
            packet.append(UInt8(locData.count))
            packet.append(locData)
            p.writeValue(packet, for: char, type: .withResponse)
            addLog("Comando de idioma enviado: \(locale)")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            connectionStatus = "Pronto para buscar"
            startScan()
        } else {
            connectionStatus = "Bluetooth desativado"
            isConnected = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? ""
        if name.contains("Galaxy Fit3") || name.contains("Fit3") {
            addLog("Galaxy Fit3 encontrada (\(name)). Conectando...")
            stopScan()
            connectedPeripheral = peripheral
            peripheral.delegate = self
            centralManager.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectionStatus = "Conectado a \(peripheral.name ?? "Galaxy Fit3")"
        addLog("Conexão estabelecida. Descobrindo serviços...")
        peripheral.discoverServices([serviceHeartRate, serviceDeviceInfo, serviceBattery, serviceSamsungData])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectionStatus = "Desconectado"
        commCharacteristic = nil
        heartRate = 0
        addLog("Pulseira desconectada. Tentando reconectar...")
        startScan() // Reconexão automática contínua
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            // Sensor de Batimentos Cardíacos
            if char.uuid == charHeartRateMeasurement {
                peripheral.setNotifyValue(true, for: char)
                addLog("Monitor de batimentos ativado!")
            }

            // Nível da Bateria da Pulseira
            if char.uuid == charBatteryLevel {
                peripheral.readValue(for: char)
                peripheral.setNotifyValue(true, for: char)
            }

            // Informações de Firmware
            if char.uuid == charFirmware {
                peripheral.readValue(for: char)
            }

            // Canal Proprietário Samsung (Comunicação/Notificações/Idioma)
            if char.uuid == charSamsungComm {
                commCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
                addLog("Canal de controle conectado!")
                sendLanguageSync(locale: "pt_BR")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        // Processa Batimento Cardíaco (Padrão 2A37)
        if characteristic.uuid == charHeartRateMeasurement {
            let flags = data[0]
            var bpm = 0
            if (flags & 0x01) == 0 {
                bpm = Int(data[1])
            } else {
                bpm = Int(data[1]) | (Int(data[2]) << 8)
            }
            if bpm > 0 {
                DispatchQueue.main.async {
                    self.heartRate = bpm
                }
            }
        }

        // Processa Nível de Bateria
        if characteristic.uuid == charBatteryLevel {
            let batt = Int(data[0])
            DispatchQueue.main.async {
                self.watchBattery = batt
            }
            addLog("Bateria da pulseira: \(batt)%")
        }

        // Processa Versão do Firmware
        if characteristic.uuid == charFirmware {
            if let fw = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.firmwareVersion = fw
                }
            }
        }
    }
}
