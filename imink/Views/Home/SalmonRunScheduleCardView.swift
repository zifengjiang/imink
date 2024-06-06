import SwiftUI
import SplatDatabase

struct SalmonRunScheduleCardView: View {
    let schedule: Schedule

    var body: some View {
        VStack{
            VStack{
                Text(schedule.formattedSalmonRunTime)
                    .font(.splatoonFont(size: 15))
                    .colorInvert()
            }
            .padding(3)
            .padding(.horizontal)
            .background(Color.secondary)
            .clipShape(Capsule())
            .padding(.bottom, 5)

            HStack{
                VStack{
                    Text(schedule._stage[0].nameId.localizedFromSplatNet)
                        .font(.splatoonFont(size: 15))
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)

                    Image(schedule._stage[0].name)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(spacing: 8){
                    HStack{
                        schedule.rule1.icon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30, alignment: .center)

                        Text(schedule.rule1.localized)
                            .font(.splatoonFont(size: 20))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                    }

                    HStack{

                        if let _boss = schedule._boss{
                            Image(_boss.name)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)

                            Text(_boss.nameId.localizedFromSplatNet)
                                .font(.splatoonFont(size: 15))
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)
                        }
                    }

                    HStack{

                        ForEach(schedule._weapons.indices, id: \.self){ index in
                            Image(schedule._weapons[index].name)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        }

                    }
                }
            }

        }
        .padding()
        .background(Color.listItemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

    //#Preview {
    //    SalmonRunScheduleCardView()
    //}
