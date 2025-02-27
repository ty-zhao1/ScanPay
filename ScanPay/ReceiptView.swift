//import SwiftUI
//import Vision
//import UIKit
//
//struct ReceiptScannerView: View {
//    @State private var showImagePicker = false
//    @State private var inputImage: UIImage?
//    @State private var recognizedText = ""
//    @State private var expensiveItems: [String] = []
//    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .camera
//    @State private var showPhotoLibraryPicker = false
//    @State private var showCameraPicker = false
//
//    var body: some View {
//        NavigationView {
//            VStack {
//                if let image = inputImage {
//                    Image(uiImage: image)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(height: 250)
//                        .padding()
//                }
//                    
//                HStack {
//                    
//                    Button("Upload Receipt") {
//                        imagePickerSourceType = .photoLibrary
//                        showImagePicker = true
//                    }
//                    .padding()
//                    
//                    Button("Capture Receipt") {
//                        imagePickerSourceType = .camera
//                        showImagePicker = true
//                    }
//                    .padding()
//
//                }
//                
//                ScrollView {
//                    Text(recognizedText)
//                        .padding()
//                }
//                .frame(height: 150)
//
//                List(expensiveItems, id: \.self) { item in
//                    Text(item)
//                }
//            }
//            .navigationTitle("Receipt Scanner")
//            .sheet(isPresented: $showImagePicker, onDismiss: processImage) {
//                ImagePicker(image: $inputImage, sourceType: imagePickerSourceType)
//            }
//        }
//    }
//
//    func processImage() {
//        guard let inputImage = inputImage else { return }
//        recognizeText(from: inputImage)
//    }
//
//    func recognizeText(from image: UIImage) {
//        guard let cgImage = image.cgImage else { return }
//        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
//        let request = VNRecognizeTextRequest { (request, error) in
//            if let error = error {
//                print("Text recognition error: \(error.localizedDescription)")
//                return
//            }
//            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
//            var recognized = ""
//            for observation in observations {
//                if let bestCandidate = observation.topCandidates(1).first {
//                    recognized += bestCandidate.string + "\n"
//                }
//            }
//            DispatchQueue.main.async {
//                recognizedText = recognized
//                expensiveItems = extractExpensiveItems(from: recognized)
//            }
//        }
//        request.recognitionLevel = .accurate
//        DispatchQueue.global(qos: .userInitiated).async {
//            do {
//                try requestHandler.perform([request])
//            } catch {
//                print("Failed to perform text recognition: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    func extractExpensiveItems(from text: String) -> [String] {
//        let threshold: Double = 5.0
//        var items: [String] = []
//        let pattern = "\\$?\\d+\\.\\d{2}"
//        guard let regex = try? NSRegularExpression(pattern: pattern) else { return items }
//        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
//        let matches = regex.matches(in: text, options: [], range: nsRange)
//        for match in matches {
//            if let range = Range(match.range, in: text) {
//                var priceString = String(text[range])
//                priceString = priceString.replacingOccurrences(of: "$", with: "")
//                if let price = Double(priceString), price > threshold {
//                    items.append("Item with price: \(price)")
//                }
//            }
//        }
//        return items
//    }
//}
//
//struct ImagePicker: UIViewControllerRepresentable {
//    @Environment(\.presentationMode) var presentationMode
//    @Binding var image: UIImage?
//    var sourceType: UIImagePickerController.SourceType = .camera
//
//    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
//        let parent: ImagePicker
//
//        init(parent: ImagePicker) {
//            self.parent = parent
//        }
//
//        func imagePickerController(_ picker: UIImagePickerController,
//                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//            if let uiImage = info[.originalImage] as? UIImage {
//                parent.image = uiImage
//            }
//            parent.presentationMode.wrappedValue.dismiss()
//        }
//    }
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(parent: self)
//    }
//
//    func makeUIViewController(context: Context) -> some UIViewController {
//        let picker = UIImagePickerController()
//        picker.delegate = context.coordinator
//        picker.sourceType = sourceType
//        return picker
//    }
//
//    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
//}
//
//struct ReceiptScannerView_Previews: PreviewProvider {
//    static var previews: some View {
//        ReceiptScannerView()
//    }
//}
