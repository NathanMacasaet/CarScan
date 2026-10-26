import SwiftUI

struct ContentView: View {
    @StateObject private var scanManager = ScanManager.shared
    @State private var isScanning = false
    @State private var showViewer = false
    @State private var modelURL: URL?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                ARViewContainer(isScanning: $isScanning)
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("CarScan")
                                .font(.title)
                                .fontWeight(.bold)
                            Text(isScanning ? "Scanning..." : "Ready to scan")
                                .font(.subheadline)
                        }
                        Spacer()
                        if isScanning {
                            Label("LIVE", systemImage: "record.circle.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()

                    Spacer()

                    if isScanning {
                        Text("\(scanManager.meshCount) mesh sections captured")
                            .font(.subheadline)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }

                    Spacer()

                    if scanManager.isExporting {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Creating 3D model...")
                                .font(.headline)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else {
                        Button {
                            if !isScanning {
                                scanManager.startNewScan()
                                isScanning = true
                            } else {
                                isScanning = false
                                scanManager.exportScan { result in
                                    switch result {
                                    case .success(let url):
                                        modelURL = url
                                        showViewer = true
                                    case .failure:
                                        showError = true
                                    }
                                }
                            }
                        } label: {
                            Text(isScanning ? "Finish & Save" : "Start Scan")
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }
            }
            .navigationDestination(isPresented: $showViewer) {
                if let modelURL {
                    ModelViewer(modelURL: modelURL)
                }
            }
            .alert("CarScan Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(scanManager.errorMessage ?? "Unable to save the scan.")
            }
        }
    }
}