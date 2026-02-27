//
//  ContentView.swift
//  TrashOhh
//
//  Created by Ledger Heath on 2023/1/12.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TextView()
                .tabItem {
                    Label("文本", systemImage: "doc.text.fill")
                }
            PictureView()
                .tabItem {
                    Label("图像", systemImage: "photo.artframe")
                }
            SoundView()
                .tabItem {
                    Label("语音", systemImage: "mic.square")
                }
        }
        .tint(.cyan)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
