import SwiftUI

struct WavePicker: View {
    @State var selected = 0
    var body: some View {
        VStack{
            Picker(selection: $selected) {
                Text("Swift").tag(0)
                Text("Java").tag(1)
            } label: {
                Text("label")
            }
            .pickerStyle(.segmented)
            Image(.copShakeup)
        }
    }
}

#Preview {
    WavePicker()
}
