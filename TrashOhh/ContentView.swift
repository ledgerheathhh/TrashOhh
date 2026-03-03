//
//  ContentView.swift
//  TrashOhh
//
//  Created by Ledger Heath on 2023/1/12.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .text

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                TextView()
            }
            .navigationViewStyle(.stack)
            .tag(AppTab.text)
            .tabItem {
                Label("文本", systemImage: "doc.text.fill")
            }

            NavigationView {
                PictureView()
            }
            .navigationViewStyle(.stack)
            .tag(AppTab.picture)
            .tabItem {
                Label("图像", systemImage: "photo.artframe")
            }

            NavigationView {
                SoundView()
            }
            .navigationViewStyle(.stack)
            .tag(AppTab.sound)
            .tabItem {
                Label("语音", systemImage: "mic.square")
            }
        }
        .tint(.teal)
    }
}

private enum AppTab: Hashable {
    case text
    case picture
    case sound
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
