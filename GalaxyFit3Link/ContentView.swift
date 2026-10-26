import SwiftUI

struct ContentView: View {
    @StateObject private var ble = BluetoothManager.shared
    @State private var testNotificationText = ""
    @State private var showingTestAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // MARK: - Barra de Status Superior
                    HStack {
                        Circle()
                            .fill(ble.isConnected ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                        Text(ble.connectionStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        if ble.isConnected {
                            Button("Desconectar") {
                                ble.disconnect()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        } else {
                            Button("Buscar") {
                                ble.startScan()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                    // MARK: - Card dos Batimentos Cardíacos (BPM)
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                            Text("Frequência Cardíaca")
                                .font(.headline)
                            Spacer()
                            Text("0x180D")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }

                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(ble.heartRate > 0 ? "\(ble.heartRate)" : "--")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("BPM")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)

                        Text(ble.isConnected ? "Monitoramento Contínuo Ativo" : "Conecte a pulseira para iniciar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)

                    // MARK: - Card Duplo de Bateria (iPhone & Galaxy Fit3)
                    HStack(spacing: 12) {
                        // Bateria do iPhone
                        VStack(spacing: 6) {
                            HStack {
                                Image(systemName: "iphone")
                                    .foregroundColor(.blue)
                                Text("iPhone")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            Text("\(ble.iPhoneBattery)%")
                                .font(.title)
                                .fontWeight(.bold)
                            ProgressView(value: Double(ble.iPhoneBattery), total: 100)
                                .accentColor(.blue)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(14)

                        // Bateria do Galaxy Fit3
                        VStack(spacing: 6) {
                            HStack {
                                Image(systemName: "applewatch.radiowaves.left.and.right")
                                    .foregroundColor(.green)
                                Text("Fit3")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            Text(ble.watchBattery > 0 ? "\(ble.watchBattery)%" : "--%")
                                .font(.title)
                                .fontWeight(.bold)
                            ProgressView(value: Double(max(0, ble.watchBattery)), total: 100)
                                .accentColor(.green)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(14)
                    }

                    // MARK: - Idioma & Notificações
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Controle & Preferências")
                            .font(.headline)

                        Button(action: {
                            ble.sendLanguageSync(locale: "pt_BR")
                        }) {
                            HStack {
                                Image(systemName: "globe.americas.fill")
                                    .foregroundColor(.blue)
                                Text("Forçar Idioma Português (PT-BR)")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(10)
                        }

                        // Teste de Notificação no Pulso
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enviar Alerta de Teste para o Pulso")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack {
                                TextField("Ex: Mensagem do WhatsApp", text: $testNotificationText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())

                                Button("Enviar") {
                                    guard !testNotificationText.isEmpty else { return }
                                    ble.sendNotificationToWatch(title: "Notificação iPhone", body: testNotificationText)
                                    testNotificationText = ""
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)

                    // MARK: - Informação do Cronômetro & Timer Nativo
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .font(.title)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Timer & Cronômetro Nativo")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text("Disponível nativamente no relógio deslizando para cima na tela inicial.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)

                    // MARK: - Logs do Sistema
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Logs de Atividade")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(ble.logs.reversed(), id: \.self) { log in
                                    Text(log)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)

                }
                .padding()
            }
            .navigationTitle("Galaxy Fit3 Link")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
