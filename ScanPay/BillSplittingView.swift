//
//  BillSplittingView.swift
//  ScanPay
//
//  Created by Adam Zhao on 2/28/25.
//

import SwiftUI
import Vision
import VisionKit

struct BillSplittingView: View {
    @ObservedObject var viewModel: ReceiptViewModel
    @State private var selectedPersonIndex = 0
    
    var body: some View {
        VStack {
            // People selection
            peopleSelectionView
            
            Divider()
            
            // Items list
            itemsListView
            
            Divider()
            
            // Totals summary
            totalsView
        }
        .navigationTitle("Split the Bill")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.addPerson()
                }) {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
    }
    
    var peopleSelectionView: some View {
        VStack {
            Text("Select Person")
                .font(.headline)
                .padding(.top)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.people.indices, id: \.self) { index in
                        Button(action: {
                            selectedPersonIndex = index
                        }) {
                            VStack {
                                Circle()
                                    .fill(viewModel.people[index].color)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        selectedPersonIndex == index ?
                                        Circle().stroke(Color.black, lineWidth: 2) : nil
                                    )
                                
                                Text(viewModel.people[index].name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button("Rename") {
                                // Rename functionality could be added here
                            }
                            
                            Button("Remove", role: .destructive) {
                                viewModel.removePerson(at: index)
                                if selectedPersonIndex >= viewModel.people.count {
                                    selectedPersonIndex = max(0, viewModel.people.count - 1)
                                }
                            }
                            .disabled(viewModel.people.count <= 1)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    var itemsListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.receipt?.items ?? []) { item in
                    HStack {
                        Button(action: {
                            let id = viewModel.people[selectedPersonIndex].id
                            viewModel.toggleItemSelection(itemID: item.id, personID: id)
                            
                        }) {
                            HStack {
                                Text(item.name)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                
                                Spacer()
                                
                                if item.price > 0 {
                                    Text("$\(String(format: "%.2f", item.price))")
                                        .font(.body)
                                }
                                
                                if item.price > 0 {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.gray, lineWidth: 1)
                                            .frame(width: 24, height: 24)
                                        
                                        let personID = viewModel.people[selectedPersonIndex].id
                                           if item.assignedTo.contains(personID) {
                                            Circle()
                                                .fill(viewModel.people[selectedPersonIndex].color)
                                                .frame(width: 16, height: 16)
                                        }
                                    }
                                } else {
                                    // For add-ons with zero price
                                    Spacer()
                                        .frame(width: 24)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(itemBackgroundColor(for: item))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(item.price <= 0) // Disable selection for zero-price add-ons
                    }
                }
            }
            .padding()
        }
    }
    
    func itemBackgroundColor(for item: ReceiptItem) -> Color {
        // If no price or add-on, return clear with slight gray
        if item.price <= 0 {
            return Color.gray.opacity(0.05)
        }
        
        // If no one has selected this item, return clear
        if item.assignedTo.isEmpty {
            return Color.clear
        }
        
        // If only the currently selected person has selected this item
        if item.assignedTo.count == 1 && item.assignedTo.contains(viewModel.people[selectedPersonIndex].id) {
            return viewModel.people[selectedPersonIndex].color.opacity(0.2)
        }
        
        // If the currently selected person has selected this item among others
        if item.assignedTo.contains(viewModel.people[selectedPersonIndex].id) {
            return Color.gray.opacity(0.3)
        }
        
        // If others have selected this item but not the current person
        return Color.gray.opacity(0.1)
    }
    
    var totalsView: some View {
        VStack {
            Text("Summary")
                .font(.headline)
                .padding(.top)
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.people.indices, id: \.self) { index in
                        HStack {
                            Circle()
                                .fill(viewModel.people[index].color)
                                .frame(width: 20, height: 20)
                            
                            Text(viewModel.people[index].name)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            if let receipt = viewModel.receipt {
                                Text("$\(String(format: "%.2f", viewModel.people[index].calculateTotal(receipt: receipt)))")
                                    .font(.title3)
                                    .bold()
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.vertical)
                    
                    HStack {
                        Text("Grand Total")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("$\(String(format: "%.2f", viewModel.receipt?.grandTotal ?? 0))")
                            .font(.title3)
                            .bold()
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
        }
    }
}
