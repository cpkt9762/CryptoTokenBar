import SwiftUI

struct TokenIconView: View {
    let symbol: String
    
    var body: some View {
        AsyncImage(url: iconURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure, .empty:
                fallbackIcon
            @unknown default:
                fallbackIcon
            }
        }
    }
    
    private var iconURL: URL? {
        let lowercased = symbol.lowercased()
        return URL(string: "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/\(lowercased).png")
    }
    
    private var fallbackIcon: some View {
        ZStack {
            Circle()
                .fill(iconGradient)
            
            Text(symbol.prefix(1))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var iconGradient: LinearGradient {
        let colors: [Color] = {
            switch symbol {
            case "BTC": return [Color.orange, Color.yellow]
            case "ETH": return [Color.purple, Color.blue]
            case "SOL": return [Color.purple, Color.pink]
            case "BNB": return [Color.yellow, Color.orange]
            case "XMR": return [Color.orange, Color.red]
            case "DOGE": return [Color.yellow, Color.orange]
            case "SUI": return [Color.blue, Color.cyan]
            default: return [Color.blue, Color.cyan]
            }
        }()
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
