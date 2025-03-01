////
////  ReceiptInfo.swift
////  ScanPay
////
////  Created by Adam Zhao on 2/26/25.
////
///
///

import SwiftUI
import Vision
import VisionKit

struct ReceiptItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let price: Double
    var isSelected: Bool = false
    var assignedTo: Set<UUID> = []
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Receipt: Identifiable {
    let id = UUID()
    var items: [ReceiptItem]
    var subtotal: Double
    var grandTotal: Double
    
    init(items: [ReceiptItem], subtotal: Double? = nil, grandTotal: Double? = nil) {
        self.items = items
        // Calculate subtotal if not provided
        self.subtotal = subtotal ?? items.reduce(0) { $0 + $1.price }
        // Use provided grandTotal or default to subtotal if not available
        self.grandTotal = grandTotal ?? self.subtotal
    }
}

struct Person: Identifiable {
    let id: UUID = UUID()
    var name: String
    var assignedItems: Set<UUID> = []
    var color: Color
    
    func calculateTotal(receipt: Receipt) -> Double {
        let itemsTotal = receipt.items
            .filter { assignedItems.contains($0.id) }
            .reduce(0) { $0 + $1.price }
        
        // Calculate proportional amount of tax, tip, etc.
        let ratio = receipt.grandTotal / receipt.subtotal
        let total = itemsTotal * ratio
        
        // Round to 2 decimal places
        return (total * 100).rounded() / 100
    }
}

// MARK: - View Models

class ReceiptViewModel: ObservableObject {
    @Published var receipt: Receipt?
    @Published var isScanning = false
    @Published var people: [Person] = []
    @Published var recognizedText: String = ""
    
    // Add a default person
    func initialize() {
        if people.isEmpty {
            people = [Person(name: "Person 1", color: .blue)]
        }
    }
    
    func addPerson() {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow]
        let newColor = colors[people.count % colors.count]
        people.append(Person(name: "Person \(people.count + 1)", color: newColor))
    }
    
    func removePerson(at index: Int) {
        guard index < people.count, people.count > 1 else { return }
        
        // Get person being removed
        let personToRemove = people[index]
        
        // Clear item assignments for this person
        if var receipt = receipt {
            var updatedItems = receipt.items
            for i in 0..<updatedItems.count {
                updatedItems[i].assignedTo.remove(personToRemove.id)
            }
            receipt.items = updatedItems
        }
        
        people.remove(at: index)
    }
    
    func toggleItemSelection(itemID: UUID, personID: UUID) {
        guard var receipt = receipt else { return }
        
        if let itemIndex = receipt.items.firstIndex(where: { $0.id == itemID }) {
            var item = receipt.items[itemIndex]
            
            if item.assignedTo.contains(personID) {
                item.assignedTo.remove(personID)
            } else {
                item.assignedTo.insert(personID)
            }
            
            receipt.items[itemIndex] = item
            self.receipt = receipt
            
            // Update person's assigned items
            if let personIndex = people.firstIndex(where: { $0.id == personID }) {
                if people[personIndex].assignedItems.contains(itemID) {
                    people[personIndex].assignedItems.remove(itemID)
                } else {
                    people[personIndex].assignedItems.insert(itemID)
                }
            }
        }
    }
    
    func parseReceiptFromText(_ text: String) {
        let lines = text.split(separator: "\n")
        var extractedItems: [ReceiptItem] = []
        var extractedSubtotal: Double?
        var extractedTotal: Double?
        
        // Keep track of the current main item and its add-ons
        var currentMainItem: String?
        var currentMainItemPrice: Double?
        var isAddOn = false
        
        for lineIndex in 0..<lines.count {
            let line = String(lines[lineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and tip suggestions
            if line.isEmpty || line.lowercased().contains("tip guide") || line.contains("%:") {
                continue
            }
            
            // Check if line starts with an asterisk, indicating it's an add-on
            isAddOn = line.trimmingCharacters(in: .whitespaces).hasPrefix("*")
            
            // Try to extract subtotal and total specially
            if line.lowercased().contains("subtotal") {
                if let priceMatch = extractPrice(from: line) {
                    extractedSubtotal = priceMatch.0
                }
                continue
            } else if (line.lowercased().contains("total") && !line.lowercased().contains("subtotal")) {
                if let priceMatch = extractPrice(from: line) {
                    extractedTotal = priceMatch.0
                }
                continue
            } else if line.lowercased().contains("tax") {
                continue
            } else if line.contains("ORDER #") || line.contains("TIP GUIDE") {
                continue
            }
            
            // Try to find price in the line
            guard let priceMatch = extractPrice(from: line) else { continue }
            let price = priceMatch.0
            
            // Extract item name by parsing the line more intelligently
            // First, try to extract the quantity (often starts with a number)
            var itemNameStartIndex = 0
            var itemName = line
            
            // Look for the pattern like "1 Item Name $19.94"
            let quantityPattern = "^\\d+"
            if let quantityRegex = try? NSRegularExpression(pattern: quantityPattern),
               let quantityMatch = quantityRegex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) {
                
                // Find where the quantity ends
                if let index = line.index(line.startIndex, offsetBy: quantityMatch.range.length, limitedBy: line.endIndex) {
                    itemNameStartIndex = line.distance(from: line.startIndex, to: index)
                }
            }
            
            // Now extract the item name between the quantity and the price
            if let priceIndex = line.lastIndex(of: "$"),
               let nameEndIndex = line.index(priceIndex, offsetBy: -1, limitedBy: line.startIndex) {
                
                let nameStartIndex = line.index(line.startIndex, offsetBy: itemNameStartIndex)
                itemName = String(line[nameStartIndex..<nameEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Handle add-ons
            if isAddOn {
                itemName = itemName.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Create an add-on item
                extractedItems.append(ReceiptItem(name: "   \(itemName)", price: price))
            } else {
                // This is a main item
                if !itemName.isEmpty {
                    extractedItems.append(ReceiptItem(name: itemName, price: price))
                }
                
                // Update current main item info
                currentMainItem = itemName
                currentMainItemPrice = price
            }
        }
        
        // Filter out any items that match the subtotal or total
        if let subtotal = extractedSubtotal {
            extractedItems = extractedItems.filter { $0.price != subtotal }
        }
        if let total = extractedTotal {
            extractedItems = extractedItems.filter { $0.price != total }
        }
        
        // Create the receipt
        if !extractedItems.isEmpty {
            self.receipt = Receipt(
                items: extractedItems,
                subtotal: extractedSubtotal,
                grandTotal: extractedTotal ?? extractedSubtotal
            )
        }
    }
    
    private func extractPrice(from text: String) -> (Double, Range<Int>)? {
        // Look for price patterns like $10.99 or 10.99
        let pattern = "\\$?(\\d+[.,]\\d{2})"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        guard let match = results.last else { return nil }
        let matchRange = match.range(at: 1)
        
        if matchRange.location != NSNotFound {
            let priceString = nsString.substring(with: matchRange)
                .replacingOccurrences(of: ",", with: ".")
            
            if let price = Double(priceString) {
                return (price, matchRange.location..<(matchRange.location + matchRange.length))
            }
        }
        
        return nil
    }
    
    // For debugging purposes
    func printRecognizedText() {
        print("Recognized Text:")
        print(recognizedText)
        
        if let receipt = receipt {
            print("\nExtracted Items:")
            for item in receipt.items {
                print("\(item.name): $\(item.price)")
            }
            print("Subtotal: $\(receipt.subtotal)")
            print("Grand Total: $\(receipt.grandTotal)")
        }
    }
}
