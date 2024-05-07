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
                    Label("Text", systemImage: "doc.text.fill")
                }
            PictureView()
                .tabItem {
                    Label("Image", systemImage: "photo.artframe")
                }
            SoundView()
                .tabItem {
                    Label("Sound", systemImage:
                            "mic.square")
                }
        }
        /*
        NavigationView{
            VStack(spacing:30){
                Image("垃圾").resizable().aspectRatio(contentMode: .fit)
                
                NavigationLink(destination: PictureView()){
                    Text("图像识别").font(.largeTitle).bold()
                }
                        
                NavigationLink(destination: TextView()){
                    Text("文本识别").font(.largeTitle).bold()
                }
                
                NavigationLink(destination: SoundView()){
                    Text("语音识别").font(.largeTitle).bold()
                }
                
            }.padding()
        }
        */
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
