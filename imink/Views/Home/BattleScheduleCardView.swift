import SwiftUI
import SplatDatabase

struct BattleScheduleCardView: View {
    var schedules: [Schedule]

    var body: some View {
        VStack{
            VStack{
                if let startTime = schedules.first?.startTime, startTime < Date(){
                    Text("Now")
                        .font(.splatoonFont(size: 15))
                        .colorInvert()
                }else{
                    Text(schedules.first!.formattedBattleTime)
                        .font(.splatoonFont(size: 15))
                        .colorInvert()
                }
            }
            .padding(3)
            .padding(.horizontal)
            .background(Color.secondary)
            .clipShape(Capsule())
            .padding(.bottom, 5)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack{
                    ForEach(schedules, id: \.id){ schedule in
                        if schedule.mode == .fest || schedule.mode == .bankara{
                            CardColumn(mode: schedule.mode, rule: schedule.rule1, stages: schedule.challengeStage, isOpen: false)
                            CardColumn(mode: schedule.mode, rule: schedule.rule2!, stages: schedule.openStage, isOpen: true)
                        }else{
                            CardColumn(mode: schedule.mode, rule: schedule.rule1, stages: schedule._stage, event: schedule.event)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.listItemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    struct CardColumn:View {

        let mode:Schedule.Mode
        let rule:Schedule.Rule
        let stages: [ImageMap]
        let event:String?
        let isOpen:Bool

        init(mode: Schedule.Mode, rule: Schedule.Rule, stages: [ImageMap], event: String? = nil, isOpen:Bool = false) {
            self.mode = mode
            self.rule = rule
            self.stages = stages
            self.event = event
            self.isOpen = isOpen
        }

        var body: some View {
            VStack(alignment: .center, spacing: 8){
                HStack(spacing:2){
                    mode.icon
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)

                    if mode == .bankara || mode == .x || mode == .event{
                        rule.icon
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                    }

                    if mode == .event{
                        Text(event!.localizedFromSplatNet)
                            .font(.splatoonFont(size: 12))
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                    }else{
                        Text(mode.localized(open: isOpen))
                            .font(.splatoonFont(size: 12))
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                    }
                }

                ForEach(stages.indices, id:\.self) { index in

                    Text(stages[index].nameId.localizedFromSplatNet)
                        .font(.splatoonFont(size: 12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.1)

                    Image(stages[index].name)
                        .resizable()
                        .aspectRatio(640 / 360, contentMode: .fill)
                        .frame(width: 640 / 6, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(UIColor.separator), lineWidth: 1)
                        )
                }
            }
            .frame(width: 640 / 6)
        }
    }

}
