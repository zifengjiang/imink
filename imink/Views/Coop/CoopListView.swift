import SwiftUI
import SplatNet3API
import IndicatorsKit

struct CoopListView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var viewModel: CoopListViewModel
    @State var activeID:String?
    @State var showFilterSheet = false
    @State var selectedRow:String?
    @State var isFirstRow = true
    

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView{
                    LazyVStack{
                        ForEach(viewModel.rows, id:\.id){ row in
                            NavigationLink {
                                TabView(selection: $selectedRow){
                                    ForEach(viewModel.rows, id:\.id){ row in
                                        CoopListDetailView(isCoop: row.isCoop, coopId: row.coop?.id, shiftId: row.card?.groupId)
                                            .scrollIndicators(.hidden)
                                            .scrollClipDisabled()
                                            .containerRelativeFrame(.horizontal)
                                            .tag(row.id)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                .edgesIgnoringSafeArea(.vertical)
                                .fixSafeareaBackground()
                                .onAppear{
                                    selectedRow = row.id
                                }
                                .toolbar {
                                    ToolbarItem {
                                        Button{
                                            moveToPreviousRow()
                                            if self.isFirstRow{
                                                Haptics.generateIfEnabled(.error)
                                            }else{
                                                Haptics.generateIfEnabled(.light)
                                            }
                                        } label: {
                                            Label {

                                            } icon: {
                                                Image(systemName: "arrowtriangle.left" + (isFirstRow ? "" : ".fill"))

                                            }

                                        }
                                    }


                                    ToolbarItem {
                                        Button{
                                            moveToNextRow()
                                            Haptics.generateIfEnabled(.light)
                                        } label: {
                                            Label {

                                            } icon: {
                                                Image(systemName: "arrowtriangle.right.fill")
                                            }

                                        }
                                    }

                                    ToolbarItem{
                                        Button{
                                            if let rowId = selectedRow, let coop = viewModel.rows.first(where: {$0.id == rowId})?.coop{

                                                print(AppState.shared.viewModelDict[coop.id]?.id)
                                                var image = CoopDetailView(id: coop.id).asUIImage(size: CGSize(width: 400, height: coop.height))
                                                let activityController = UIActivityViewController(
                                                    activityItems: [image], applicationActivities: nil)
                                                let vc = UIApplication.shared.windows.first!.rootViewController
                                                vc?.present(activityController, animated: true)
                                                AppState.shared.viewModelDict[coop.id] = nil
                                            }
                                        }label:{
                                            Image(systemName: "square.and.arrow.up")
                                        }
                                    }

                                }

                            } label: {
                                CoopListRowView(isCoop: row.isCoop, coop: row.coop, card: row.card)
                                    .id(row.id)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .scrollTargetLayout()
                }
                .refreshable {
                    guard AppState.shared.isLogin else { return }
                    await SN3Client.shared.fetchCoops()
                }
                .scrollPosition(id: $activeID, anchor: .bottom)
                .fixSafeareaBackground()
                .modifier(LoginViewModifier(isLogin: AppState.shared.isLogin, iconName: "TabBarSalmonRun"))
                .navigationTitle(viewModel.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: activeID) { oldValue, newValue in
                    if newValue == viewModel.rows.last?.id {
                        Task{
                            await viewModel.loadMore()
                        }
                    }
                }
                .onChange(of: selectedRow, { oldValue, newValue in
                    proxy.scrollTo(newValue,anchor: .center)
                    self.isFirstRow = newValue == viewModel.rows.first?.id
                    if newValue == viewModel.rows.last?.id {
                        Task{
                            await viewModel.loadMore()
                        }
                    }
                })
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button{
                            showFilterSheet = true
                        } label: {
                                /// Filter
                            Label("11", systemImage: "line.horizontal.3.decrease.circle")
                        }
                    }
                }
                .toolbarTitleMenu {
                    ForEach(CoopRule.allCases, id:\.rawValue){rule in
                        Button{
                            viewModel.filter.rules.removeAll()
                            if rule != .ALL{
                                viewModel.filter.rules.insert(rule.rawValue)
                            }
                            viewModel.navigationTitle = rule.name
                            guard AppState.shared.isLogin else { return }
                            Task{
                                await viewModel.loadCoops()
                            }
                        } label: {
                            Label(
                                title: { Text("\(rule.name)") },
                                icon: { rule.icon }
                            )
                        }
                    }
                }
            }

        }
        .sheet(isPresented: $showFilterSheet){
            CoopFilterView(showFilterView: $showFilterSheet, filter: $viewModel.filter){
                viewModel.cancel()
                guard AppState.shared.isLogin else { return }
                await viewModel.loadCoops()
            }
        }
    }

    struct CustomTabView<Content: View>: View {
        @Binding var selection: String?
        @ViewBuilder var content: () -> Content
        var body: some View {
            ScrollView(.horizontal){
                LazyHStack(spacing: 0){
                    content()
                }
            }
            .scrollPosition(id: $selection)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
        }
    }

    private func moveToNextRow(){
        if let index = viewModel.rows.firstIndex(where: {$0.id == selectedRow}), index < viewModel.rows.count - 1{
            withAnimation{
                selectedRow = viewModel.rows[index + 1].id
            }
            self.isFirstRow = false
        }
    }

    private func moveToPreviousRow(){
        if let index = viewModel.rows.firstIndex(where: {$0.id == selectedRow}){
            if index > 0{
                withAnimation{
                    selectedRow = viewModel.rows[index - 1].id
                }
            }else{
                self.isFirstRow = true
            }
        }
    }


}


#Preview {
    CoopListView()
}
