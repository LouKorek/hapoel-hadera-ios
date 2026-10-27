import ActivityKit
import SwiftUI
import WidgetKit

// Lock Screen card + Dynamic Island for a live Hapoel Hadera match.
// Layout mirrors the site's live strip: home team on the leading side, away
// on the trailing side, score in the middle, status and last event below.
// Text direction follows the device language (Hebrew → RTL) automatically.

private let clubRed = Color(red: 0.83, green: 0.20, blue: 0.18)
private let ink = Color(red: 0.06, green: 0.06, blue: 0.08)

@main
struct LiveMatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        LiveMatchWidget()
    }
}

struct LiveMatchWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveMatchAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(ink)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: context.attributes.url))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TeamName(context.attributes.homeName, logo: context.attributes.homeLogo, ours: context.attributes.ourSide == "home")
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TeamName(context.attributes.awayName, logo: context.attributes.awayLogo, ours: context.attributes.ourSide == "away")
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    ScoreBlock(home: context.state.homeScore, away: context.state.awayScore, size: 30)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    StatusLine(state: context.state)
                        .padding(.horizontal, 6)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Crest(url: context.attributes.ourSide == "home" ? context.attributes.homeLogo : context.attributes.awayLogo, ours: true, size: 18)
                    Text("\(context.state.homeScore)–\(context.state.awayScore)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .environment(\.layoutDirection, .leftToRight)
                }
            } compactTrailing: {
                MinuteText(state: context.state, size: 12)
                    .foregroundStyle(context.state.live ? clubRed : .secondary)
                    .lineLimit(1)
            } minimal: {
                Text("\(context.state.homeScore)–\(context.state.awayScore)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .environment(\.layoutDirection, .leftToRight)
            }
            .widgetURL(URL(string: context.attributes.url))
            .keylineTint(clubRed)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<LiveMatchAttributes>

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                TeamName(context.attributes.homeName, logo: context.attributes.homeLogo, ours: context.attributes.ourSide == "home")
                    .frame(maxWidth: .infinity, alignment: .leading)
                ScoreBlock(home: context.state.homeScore, away: context.state.awayScore, size: 34)
                TeamName(context.attributes.awayName, logo: context.attributes.awayLogo, ours: context.attributes.ourSide == "away")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            StatusLine(state: context.state)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
    }
}

// Crest + team name. The crest comes from the shared container the app
// filled (see CrestStore); until it is there — or when the opponent has
// none — a neutral shield stands in.
private struct TeamName: View {
    let name: String
    let logo: String
    let ours: Bool
    init(_ name: String, logo: String, ours: Bool) { self.name = name; self.logo = logo; self.ours = ours }
    var body: some View {
        VStack(spacing: 4) {
            Crest(url: logo, ours: ours, size: 30)
            Text(name)
                .font(.system(size: 13, weight: .heavy))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
        }
    }
}

private struct Crest: View {
    let url: String
    let ours: Bool
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.92))
            if let img = CrestStore.image(for: url) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.1)
            } else {
                Image(systemName: "shield.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(ours ? clubRed : Color(white: 0.6))
            }
        }
        .frame(width: size, height: size)
    }
}

// Score digits are laid out LTR like the site's scoreboard, so the home
// score always sits next to the home team whatever the device language.
private struct ScoreBlock: View {
    let home: Int
    let away: Int
    let size: CGFloat
    var body: some View {
        HStack(spacing: 2) {
            Text("\(home)")
            Text("–").foregroundStyle(.white.opacity(0.7))
            Text("\(away)")
        }
        .font(.system(size: size, weight: .black, design: .rounded))
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .environment(\.layoutDirection, .leftToRight)
    }
}

// The minute. With a clock interval from the server (1.6+) the card counts
// by itself between pushes — "47:12" like a broadcast clock, frozen at the
// edge of the half (45:00, or 48:00 once added time is known) until the next
// phase push. Otherwise the last pushed minute ("67'"), or the status word.
private struct MinuteText: View {
    let state: LiveMatchAttributes.ContentState
    let size: CGFloat
    var body: some View {
        if state.live, let s = state.clockStart, let e = state.clockEnd, e > s {
            Text(timerInterval: Date(timeIntervalSince1970: s)...Date(timeIntervalSince1970: e), countsDown: false, showsHours: false)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .environment(\.layoutDirection, .leftToRight)
        } else {
            Text(state.live ? (state.minute.isEmpty ? state.status : state.minute) : state.status)
                .font(.system(size: size, weight: .bold))
        }
    }
}

// "● 47:12 · בעיצומו" on the leading side, the last event on the trailing side.
private struct StatusLine: View {
    let state: LiveMatchAttributes.ContentState
    var hasClock: Bool { state.live && state.clockStart != nil && state.clockEnd != nil }
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if state.live {
                    Circle().fill(clubRed).frame(width: 7, height: 7)
                }
                if hasClock {
                    MinuteText(state: state, size: 15)
                        .foregroundStyle(Color(red: 0.95, green: 0.70, blue: 0.24))
                    Text(state.status)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text(state.minute.isEmpty ? state.status : "\(state.status) · \(state.minute)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(state.live ? .white : .white.opacity(0.75))
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Color.white.opacity(0.10), in: Capsule())
            if !state.lastEvent.isEmpty {
                Text(state.lastEvent)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Spacer(minLength: 0)
            }
        }
    }
}
