//
//  ContentView.swift
//  ScanPay
//
//  Created by Adam Zhao on 4/22/24.
//
import SwiftUI
import VisionKit
import Vision
//

struct ContentView: View {
    @StateObject private var viewModel = ReceiptViewModel()
    @State private var showingImagePicker = false
    @State private var showingScanner = false
    @State private var selectedImage: UIImage?
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.receipt == nil {
                    receiptScanView
                } else {
                    NavigationLink(destination: BillSplittingView(viewModel: viewModel)) {
                        Text("Continue to Bill Splitting")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.bottom)
                    
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Extracted Items")
                                .font(.headline)
                                .padding([.horizontal, .top])
                            
                            ForEach(viewModel.receipt?.items ?? []) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.body)
                                    Spacer()
                                    Text("$\(String(format: "%.2f", item.price))")
                                        .font(.body)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Subtotal")
                                    .font(.headline)
                                Spacer()
                                Text("$\(String(format: "%.2f", viewModel.receipt?.subtotal ?? 0))")
                                    .font(.headline)
                            }
                            .padding(.horizontal)
                            
                            HStack {
                                Text("Total")
                                    .font(.headline)
                                Spacer()
                                Text("$\(String(format: "%.2f", viewModel.receipt?.grandTotal ?? 0))")
                                    .font(.headline)
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                            
                            Button("Scan Another Receipt") {
                                viewModel.receipt = nil
                                viewModel.recognizedText = ""
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Receipt Scanner")
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: sourceType)
                    .onDisappear {
                        if let image = selectedImage {
                            recognizeText(from: image)
                        }
                    }
            }
            .sheet(isPresented: $showingScanner) {
                ScannerView { result in
                    switch result {
                    case .success(let text):
                        viewModel.recognizedText = text
                        viewModel.parseReceiptFromText(text)
                        // Debug print
                        viewModel.printRecognizedText()
                    case .failure(let error):
                        print("Scanning error: \(error.localizedDescription)")
                    }
                    showingScanner = false
                }
            }
            .onAppear {
                viewModel.initialize()
            }
        }
    }
    
    var receiptScanView: some View {
        VStack(spacing: 30) {
            VStack {
                Image(systemName: "doc.text.viewfinder")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                Text("Scan or select a receipt to get started")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            VStack(spacing: 15) {
                Button(action: {
                    sourceType = .camera
                    showingImagePicker = true
                }) {
                    Label("Take a Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    sourceType = .photoLibrary
                    showingImagePicker = true
                }) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    showingScanner = true
                }) {
                    Label("Use Document Scanner", systemImage: "doc.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // Demo data for testing with the example receipt you provided
                    let demoItems = [
                        ReceiptItem(name: "1 Fish Cake Soft Tofu", price: 19.94),
                        ReceiptItem(name: "   Not Spicy", price: 0.0),
                        ReceiptItem(name: "1 Beef Soft Tofu", price: 19.94),
                        ReceiptItem(name: "   Mild", price: 0.0),
                        ReceiptItem(name: "   Add Egg", price: 0.50),
                        ReceiptItem(name: "1 Haemul Pajun", price: 22.69),
                        ReceiptItem(name: "1 Seafood Soft Tofu", price: 19.94),
                        ReceiptItem(name: "   Medium", price: 0.50),
                        ReceiptItem(name: "   Add Egg", price: 1.00),
                        ReceiptItem(name: "   Add Rice Cake", price: 0.0)
                    ]
                    viewModel.receipt = Receipt(items: demoItems, subtotal: 84.51, grandTotal: 92.22)
                }) {
                    Label("Use Demo Receipt", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        // Create a new image-request handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        
        // Create a new request to recognize text
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("Failed to recognize text: \(error.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            DispatchQueue.main.async {
                viewModel.recognizedText = recognizedText
                viewModel.parseReceiptFromText(recognizedText)
                // Debug print
                viewModel.printRecognizedText()
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Process the request
        do {
            try requestHandler.perform([request])
        } catch {
            print("Unable to perform the request: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
