import AppKit
import SwiftUI
import libdawnUI

struct AboutView: View {
    let content: AboutContent
    @State private var needsUpdate: Bool = false
    @State private var isCheckingUpdates: Bool = false

    
    private func checkUpdates() {
        
        /// This View does not have a working implementation.
        /// This is a Mock that does a simple animation to preview future function.
        
        Task {
            DispatchQueue.main.async {
                withAnimation(.snappy) {
                    isCheckingUpdates = true
                }
            }
            
            try? await Task.sleep(for: .seconds(3))
            
            DispatchQueue.main.async {
                withAnimation(.snappy) {
                    isCheckingUpdates = false
                    needsUpdate = true
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            
            Spacer()
            
            VStack(spacing: 0) {
                Image(systemName: "sun.horizon")
                    .font(.system(size: 64))
                Text("dawn")
                    .font(.system(size: 32))
            }
            
            VStack(spacing: 4) {
                Text("Version \(content.appVersion)")
                    .font(DawnTextStyle.secondary)
                    .foregroundStyle(DawnColors.secondaryForeground)
                Text("\(content.ticket.commit.displayName)")
                    .font(DawnTextStyle.secondary)
                    .foregroundStyle(DawnColors.secondaryForeground)

            }

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("Dawn is designed by")
                        .font(DawnTextStyle.secondary)
                        .foregroundStyle(DawnColors.secondaryForeground)
                    
                    DButton(style: .linkSecondary) {
                        NSWorkspace.shared.open(content.ticket.marketingURL)
                    } content: {
                        Text("OpenDawn")
                    }
                }
                
                HStack(spacing: 4) {
                    Text("and is open source, under the")
                        .font(DawnTextStyle.secondary)
                        .foregroundStyle(DawnColors.secondaryForeground)
                    
                    DButton(style: .linkSecondary) {
                        NSWorkspace.shared.open(content.ticket.licenseURL)
                    } content: {
                        Text(verbatim: content.ticket.license)
                    }
                    
                    Text("license.")
                        .font(DawnTextStyle.secondary)
                        .foregroundStyle(DawnColors.secondaryForeground)
                }
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                DButton(style: .secondary) {
                    NSWorkspace.shared.open(content.ticket.commit.url)
                } content: {
                    Text("GitHub")
                } leading: {
                    Image(systemName: "ellipsis.curlybraces")
                }

                DButton(style: .secondary) {
                    NSWorkspace.shared.open(content.ticket.marketingURL)
                } content: {
                    Text("Give us Feedback")
                } leading: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }

                if needsUpdate {
                    VStack {
                        DButton(style: .link) {
                            print("changelog")
                        } content: {
                            Text("What's new in 0.1.1")
                        } trailing: {
                            Image(systemName: "arrow.up.forward.square")
                        }
                        
                        DButton(style: .primary) {
                            print("update now")
                        } content: {
                            Text("Update Now")
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    VStack {
                        
                        /// this empty button is here to take enough
                        /// space so the layout doesn't shift when
                        /// an actual changelog button is shown
                        DButton(style: .link) {
                        } content: {
                            Text(" ")
                        }
                        
                        DButton(style: .secondary) {
                            checkUpdates()
                        } content: {
                            if isCheckingUpdates {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            
                            Text("Check for Updates")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isCheckingUpdates)
                    }
                }
            }
        }
        .padding(16)
        .background {
            DawnColors.primaryBackground
        }
        
    }
}
