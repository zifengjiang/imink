import SwiftUI

struct CoopDetailContainer: View {
    let rows: [CoopListRowModel]
    @Binding var selectedRow: String?
    @ObservedObject var viewModel: CoopListViewModel
    
    var body: some View {
        TabView(selection: $selectedRow) {
            ForEach(rows, id: \.id) { row in
                CoopListDetailView(
                    isCoop: row.isCoop, 
                    coopId: row.coop?.id, 
                    shiftId: row.card?.groupId
                )
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .containerRelativeFrame(.horizontal)
                .tag(row.id)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .edgesIgnoringSafeArea(.vertical)
        .fixSafeareaBackground()
//        .onAppear {
//            if let firstRow = rows.first {
//                selectedRow = firstRow.id
//                viewModel.loadCurrentCoopFavoriteStatus(for: firstRow.id)
//            }
//        }
        .toolbar {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    moveToPreviousRow()
                    Haptics.generateIfEnabled(isFirstRow ? .error : .light)
                } label: {
                    Image("KEEP")
                        .resizable()
                        .scaledToFill()
                        .rotationEffect(.degrees(180))
                        .overlay(isFirstRow ? Color(.gray) : Color(.accent))
                        .mask {
                            Image("KEEP")
                                .resizable()
                                .scaledToFit()
                                .rotationEffect(.degrees(180))
                        }
                        .frame(width: 20*1.2, height: 10*1.2)
                }
                
                Button {
                    moveToNextRow()
                    Haptics.generateIfEnabled(.light)
                } label: {
                    Image("KEEP")
                        .resizable()
                        .scaledToFill()
                        .overlay(Color(.accent))
                        .mask {
                            Image("KEEP")
                                .resizable()
                                .scaledToFit()
                        }
                        .frame(width: 20*1.2, height: 10*1.2)
                }
                
                Button {
                    Task {
                        await viewModel.toggleFavorite(for: selectedRow)
                    }
                    Haptics.generateIfEnabled(.light)
                } label: {
                    Image(systemName: viewModel.currentCoopIsFavorite ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.currentCoopIsFavorite ? .red : .accentColor)
                        .font(.system(size: 18))
                }
                
                Button {
                    Haptics.generateIfEnabled(.medium)
                    if let rowId = selectedRow, let coop = rows.first(where: {$0.id == rowId})?.coop {
                        let image = CoopDetailView(id: coop.id).asUIImage(size: CGSize(width: 400, height: coop.height))
                        let activityController = UIActivityViewController(
                            activityItems: [image], applicationActivities: nil)
                        let vc = UIApplication.shared.windows.first!.rootViewController
                        vc?.present(activityController, animated: true)
                        AppState.shared.viewModelDict[coop.id] = nil
                    }
                } label: {
                    Image("share")
                        .resizable()
                        .scaledToFit()
                        .overlay(Color(.accent))
                        .mask {
                            Image("share")
                                .resizable()
                                .scaledToFit()
                        }
                        .frame(width: 20*1.2)
                        .offset(y: -4)
                }
            }
        }
    }
    
    private var isFirstRow: Bool {
        selectedRow == rows.first?.id
    }
    
    private func moveToNextRow() {
        if let index = rows.firstIndex(where: {$0.id == selectedRow}), index < rows.count - 1 {
            withAnimation {
                selectedRow = rows[index + 1].id
            }
        }
    }
    
    private func moveToPreviousRow() {
        if let index = rows.firstIndex(where: {$0.id == selectedRow}), index > 0 {
            withAnimation {
                selectedRow = rows[index - 1].id
            }
        }
    }
}
