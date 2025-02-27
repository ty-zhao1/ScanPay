//
//  ReceiptInfo.swift
//  ScanPay
//
//  Created by Adam Zhao on 2/26/25.
//

import SwiftUI
import Foundation
import CoreImage
import Vision

class ReceiptScannerModel: ObservableObject {
    @Published var receipt = Receipt()
    @Published var isScanning = false
    @Published var capturedImage: UIImage?
    @Published var processingStatus = ""
    @Published var restaurantInfo: RestaurantInfo?
    
    func processReceipt(image: UIImage) {
        self.capturedImage = image
        self.processingStatus = "Processing receipt..."
        
        // Convert UIImage to CIImage
        guard let ciImage = CIImage(image: image) else {
            self.processingStatus = "Failed to process image"
            return
        }
        
        // Perform text recognition
        recognizeText(ciImage: ciImage)
    }
    
    private func recognizeText(ciImage: CIImage) {
        // Create a new request to recognize text
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.processingStatus = "Error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    self.processingStatus = "No text detected"
                }
                return
            }
            
            // Process the recognized text
            self.parseReceiptText(observations: observations)
        }
        
        // Configure the request to use accurate mode
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Create a request handler
        let requestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.processingStatus = "Failed to perform text recognition: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func parseReceiptText(observations: [VNRecognizedTextObservation]) {
        // Extract text from observations
        let recognizedText = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        
        // Create a new receipt
        var newReceipt = Receipt()
        var newRestaurantInfo = RestaurantInfo()
        
        // First pass: extract restaurant information and categorize lines
        var itemSection = false
        var summarySection = false
        
        // Try to identify the restaurant name and address (usually at the top)
        if recognizedText.count > 0 {
            newRestaurantInfo.name = recognizedText[0]
            
            // Look for address patterns in the first few lines
            for i in 1..<min(5, recognizedText.count) {
                let line = recognizedText[i]
                
                // Check for address patterns (city, state zip)
                if line.contains(",") && (line.contains("CA") || line.contains("NY") || line.contains(" ")) {
                    newRestaurantInfo.address.append(line)
                }
                // Check for phone number pattern
                else if line.contains("(") && line.contains(")") && line.contains("-") {
                    newRestaurantInfo.phone = line
                }
            }
        }
        
        // Second pass: categorize lines and extract items
        var itemLines: [String] = []
        var summaryLines: [String] = []
        
        for line in recognizedText {
            // Detect item section
            if line.contains("DESCRIPTION") || line.contains("QT") || line.contains("ITEM") {
                itemSection = true
                summarySection = false
                continue
            }
            
            // Detect summary section
            if line.contains("SUBTOTAL") || line.contains("TAX") || (line.contains("TOTAL") && !line.contains("SUBTOTAL")) {
                itemSection = false
                summarySection = true
            }
            
            if itemSection {
                itemLines.append(line)
            } else if summarySection {
                summaryLines.append(line)
            }
        }
        
        // Process item lines
        for i in 0..<itemLines.count {
            let line = itemLines[i]
            
            // Skip lines that are likely modifiers (often start with * or spaces)
            if line.trimmingCharacters(in: .whitespaces).starts(with: "*") {
                // Try to associate this modifier with the previous item
                if let lastItem = newReceipt.items.last {
                    let modifierText = line.trimmingCharacters(in: .whitespaces)
                    let updatedName = lastItem.name + " (" + modifierText + ")"
                    
                    // Create a new item with the updated name but keep the same price
                    let updatedItem = ReceiptItem(name: updatedName, price: lastItem.price)
                    
                    // Replace the last item with the updated one
                    newReceipt.items[newReceipt.items.count - 1] = updatedItem
                }
                continue
            }
            
            // Look for item and price pattern using improved regex
            if let (itemName, price) = extractItemAndPrice(from: line) {
                // Validate price (shouldn't be extremely high for a typical receipt item)
                if price < 1000.0 {
                    newReceipt.items.append(ReceiptItem(name: itemName, price: price))
                }
            }
        }
        
        // Process summary lines
        for line in summaryLines {
            // Extract subtotal
            if line.lowercased().contains("subtotal") {
                if let price = extractPrice(from: line, maxReasonableValue: 1000.0) {
                    newReceipt.subtotal = price
                }
            }
            
            // Extract tax
            if line.lowercased().contains("tax") && !line.lowercased().contains("subtotal") {
                if let price = extractPrice(from: line, maxReasonableValue: 200.0) {
                    newReceipt.tax = price
                }
            }
            
            // Extract total
            if line.lowercased().contains("total") && !line.lowercased().contains("subtotal") {
                if let price = extractPrice(from: line, maxReasonableValue: 1000.0) {
                    newReceipt.total = price
                }
            }
        }
        
        // If we didn't find a subtotal, calculate it from items
        if newReceipt.subtotal == 0 && !newReceipt.items.isEmpty {
            newReceipt.subtotal = newReceipt.items.reduce(0) { $0 + $1.price }
        }
        
        // If we didn't find a total, calculate it
        if newReceipt.total == 0 {
            newReceipt.total = newReceipt.subtotal + newReceipt.tax
        }
        
        DispatchQueue.main.async {
            self.receipt = newReceipt
            self.restaurantInfo = newRestaurantInfo
            self.processingStatus = newReceipt.items.isEmpty ? "No items detected" : "Processing complete"
        }
    }
    
    private func extractItemAndPrice(from line: String) -> (String, Double)? {
        // Pattern: Item description followed by price at the end
        // This regex looks for: any text, followed by whitespace, followed by $ and digits
        let pattern = "(.+?)\\s+\\$(\\d+\\.\\d{2}|\\d+)$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let nsString = line as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        if let match = regex.firstMatch(in: line, range: range) {
            let itemNameRange = match.range(at: 1)
            let priceRange = match.range(at: 2)
            
            if itemNameRange.location != NSNotFound && priceRange.location != NSNotFound {
                let itemName = nsString.substring(with: itemNameRange).trimmingCharacters(in: .whitespacesAndNewlines)
                let priceString = nsString.substring(with: priceRange)
                
                if let price = Double(priceString), price < 1000.0 {
                    return (itemName, price)
                }
            }
        }
        
        // Alternative pattern: Look for number at start, followed by text, followed by price
        let altPattern = "^(\\d+)\\s+(.+?)\\s+\\$(\\d+\\.\\d{2}|\\d+)$"
        guard let altRegex = try? NSRegularExpression(pattern: altPattern) else {
            return nil
        }
        
        if let match = altRegex.firstMatch(in: line, range: range) {
            let quantityRange = match.range(at: 1)
            let itemNameRange = match.range(at: 2)
            let priceRange = match.range(at: 3)
            
            if quantityRange.location != NSNotFound && itemNameRange.location != NSNotFound && priceRange.location != NSNotFound {
                let quantity = nsString.substring(with: quantityRange)
                let itemName = nsString.substring(with: itemNameRange).trimmingCharacters(in: .whitespacesAndNewlines)
                let priceString = nsString.substring(with: priceRange)
                
                if let price = Double(priceString), price < 1000.0 {
                    return ("\(quantity) \(itemName)", price)
                }
            }
        }
        
        return nil
    }
    
    private func extractPrice(from line: String, maxReasonableValue: Double = 1000.0) -> Double? {
        // This regex looks for $ followed by digits and optional decimal point
        let pattern = "\\$(\\d+\\.\\d{2}|\\d+)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let nsString = line as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        if let match = regex.firstMatch(in: line, range: range) {
            let priceRange = match.range(at: 1)
            
            if priceRange.location != NSNotFound {
                let priceString = nsString.substring(with: priceRange)
                if let price = Double(priceString), price < maxReasonableValue {
                    return price
                }
            }
        }
        
        return nil
    }
}

// Extended data models
struct ReceiptItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
}

struct Receipt {
    var items: [ReceiptItem] = []
    var subtotal: Double = 0.0
    var tax: Double = 0.0
    var total: Double = 0.0
}

struct RestaurantInfo {
    var name: String = ""
    var address: [String] = []
    var phone: String = ""
}



/*-----------------------THIS ONE IS WORKING---------------------------------------*/
//struct ReceiptItem: Identifiable {
//    let id = UUID()
//    let name: String
//    let price: Double
//}
//
//struct Receipt {
//    var items: [ReceiptItem] = []
//    var subtotal: Double = 0.0
//    var total: Double = 0.0
//}
//
//class ReceiptScannerModel: ObservableObject {
//    @Published var receipt = Receipt()
//    @Published var isScanning = false
//    @Published var capturedImage: UIImage?
//    @Published var processingStatus = ""
//    
//    func processReceipt(image: UIImage) {
//        self.capturedImage = image
//        self.processingStatus = "Processing receipt..."
//        
//        // Convert UIImage to CIImage
//        guard let ciImage = CIImage(image: image) else {
//            self.processingStatus = "Failed to process image"
//            return
//        }
//        
//        // Perform text recognition
//        recognizeText(ciImage: ciImage)
//    }
//    
//    private func recognizeText(ciImage: CIImage) {
//        // Create a new request to recognize text
//        let request = VNRecognizeTextRequest { [weak self] request, error in
//            guard let self = self else { return }
//            
//            if let error = error {
//                DispatchQueue.main.async {
//                    self.processingStatus = "Error: \(error.localizedDescription)"
//                }
//                return
//            }
//            
//            guard let observations = request.results as? [VNRecognizedTextObservation] else {
//                DispatchQueue.main.async {
//                    self.processingStatus = "No text detected"
//                }
//                return
//            }
//            
//            // Process the recognized text
//            self.parseReceiptText(observations: observations)
//        }
//        
//        // Configure the request to use accurate mode
//        request.recognitionLevel = .accurate
//        request.usesLanguageCorrection = true
//        
//        // Create a request handler
//        let requestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
//        
//        DispatchQueue.global(qos: .userInitiated).async {
//            do {
//                try requestHandler.perform([request])
//            } catch {
//                DispatchQueue.main.async {
//                    self.processingStatus = "Failed to perform text recognition: \(error.localizedDescription)"
//                }
//            }
//        }
//    }
//    
//    private func parseReceiptText(observations: [VNRecognizedTextObservation]) {
//        // Extract text from observations
//        var recognizedText = observations.compactMap { observation in
//            observation.topCandidates(1).first?.string
//        }
//        
//        // Process the text to extract items and prices
//        var newReceipt = Receipt()
//        var subtotalFound = false
//        var totalFound = false
//        
//        for line in recognizedText {
//            // Look for item and price patterns
//            if let (itemName, price) = extractItemAndPrice(from: line) {
//                newReceipt.items.append(ReceiptItem(name: itemName, price: price))
//            }
//            
//            // Look for subtotal
//            if line.lowercased().contains("subtotal") {
//                if let price = extractPrice(from: line) {
//                    newReceipt.subtotal = price
//                    subtotalFound = true
//                }
//            }
//            
//            // Look for total
//            if line.lowercased().contains("total") && !line.lowercased().contains("subtotal") {
//                if let price = extractPrice(from: line) {
//                    newReceipt.total = price
//                    totalFound = true
//                }
//            }
//        }
//        
//        // If we didn't find a subtotal, calculate it
//        if !subtotalFound {
//            newReceipt.subtotal = newReceipt.items.reduce(0) { $0 + $1.price }
//        }
//        
//        // If we have items but no total was found
//        if !totalFound && !newReceipt.items.isEmpty {
//            // Assume the total is the subtotal for now
//            newReceipt.total = newReceipt.subtotal
//        }
//        
//        DispatchQueue.main.async {
//            self.receipt = newReceipt
//            self.processingStatus = newReceipt.items.isEmpty ? "No items detected" : "Processing complete"
//        }
//    }
//    
//    private func extractItemAndPrice(from line: String) -> (String, Double)? {
//        // This is a simple regex pattern for item and price
//        // Format expected: Item name $price or Item name price
//        let pattern = "(.+?)\\s+\\$?(\\d+\\.\\d{2}|\\d+)"
//        
//        guard let regex = try? NSRegularExpression(pattern: pattern) else {
//            return nil
//        }
//        
//        let nsString = line as NSString
//        let range = NSRange(location: 0, length: nsString.length)
//        
//        if let match = regex.firstMatch(in: line, range: range) {
//            let itemNameRange = match.range(at: 1)
//            let priceRange = match.range(at: 2)
//            
//            if itemNameRange.location != NSNotFound && priceRange.location != NSNotFound {
//                let itemName = nsString.substring(with: itemNameRange).trimmingCharacters(in: .whitespacesAndNewlines)
//                let priceString = nsString.substring(with: priceRange)
//                
//                if let price = Double(priceString) {
//                    return (itemName, price)
//                }
//            }
//        }
//        
//        return nil
//    }
//    
//    private func extractPrice(from line: String) -> Double? {
//        // Extract a price from a line, regardless of context
//        let pattern = "\\$?(\\d+\\.\\d{2}|\\d+)"
//        
//        guard let regex = try? NSRegularExpression(pattern: pattern) else {
//            return nil
//        }
//        
//        let nsString = line as NSString
//        let range = NSRange(location: 0, length: nsString.length)
//        
//        if let match = regex.firstMatch(in: line, range: range) {
//            let priceRange = match.range(at: 1)
//            
//            if priceRange.location != NSNotFound {
//                let priceString = nsString.substring(with: priceRange)
//                return Double(priceString)
//            }
//        }
//        
//        return nil
//    }
//}
