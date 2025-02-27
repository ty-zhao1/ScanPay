//
//  ContentView.swift
//  ScanPay
//
//  Created by Adam Zhao on 4/22/24.
//
import SwiftUI

//


//// Fixed ImagePicker implementation
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var onImagePicked: (UIImage) -> Void
        
        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// Enhanced ContentView to display restaurant info and better item display
struct ContentView: View {
    @StateObject private var viewModel = ReceiptScannerModel()
    @State private var showingImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    if let image = viewModel.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    
                    if !viewModel.processingStatus.isEmpty {
                        Text(viewModel.processingStatus)
                            .foregroundColor(viewModel.processingStatus.contains("Error") || viewModel.processingStatus.contains("No") ? .red : .blue)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    HStack(spacing: 15) {
                        Button(action: {
                            self.sourceType = .photoLibrary
                            self.showingImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Choose Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            self.sourceType = .camera
                            self.showingImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "camera")
                                Text("Take Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let restaurantInfo = viewModel.restaurantInfo, !restaurantInfo.name.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(restaurantInfo.name)
                                .font(.headline)
                            
                            ForEach(restaurantInfo.address, id: \.self) { line in
                                Text(line)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            if !restaurantInfo.phone.isEmpty {
                                Text(restaurantInfo.phone)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    if !viewModel.receipt.items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Items")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.receipt.items) { item in
                                HStack {
                                    Text(item.name)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Text("$\(String(format: "%.2f", item.price))")
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            
                            Divider()
                                .padding(.vertical)
                            
                            VStack(spacing: 10) {
                                Text("Summary")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                HStack {
                                    Text("Subtotal")
                                    Spacer()
                                    Text("$\(String(format: "%.2f", viewModel.receipt.subtotal))")
                                }
                                .padding(.horizontal)
                                
                                HStack {
                                    Text("Tax")
                                    Spacer()
                                    Text("$\(String(format: "%.2f", viewModel.receipt.tax))")
                                }
                                .padding(.horizontal)
                                
                                HStack {
                                    Text("Total").bold()
                                    Spacer()
                                    Text("$\(String(format: "%.2f", viewModel.receipt.total))").bold()
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    } else if viewModel.processingStatus == "Processing complete" {
                        VStack {
                            Spacer()
                            Text("No items detected. Please try scanning again with a clearer image.")
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding()
                            Spacer()
                        }
                    } else if viewModel.processingStatus.isEmpty {
                        VStack {
                            Spacer()
                            Text("Scan a receipt to get started")
                                .foregroundColor(.gray)
                                .padding()
                            Spacer()
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Receipt Scanner")
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: sourceType, onImagePicked: { image in
                    viewModel.processReceipt(image: image)
                })
            }
        }
    }
}

#Preview {
    ContentView()
}
