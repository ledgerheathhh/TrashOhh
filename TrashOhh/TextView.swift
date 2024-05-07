//
//  TextView.swift
//  TrashOhh
//
//  Created by Ledger Heath on 2023/1/14.
//
import CoreML
import SwiftUI

struct TextView: View {
    @State private var input:String = ""
    @State private var a:Int? = -1
    //let model = text_model()
    let model: text_model = {
    do {
        let config = MLModelConfiguration()
        return try text_model(configuration: config)
    } catch {
        print(error)
        fatalError("Couldn't create model")
    }
    }()
    @State var img = "垃圾箱蓝"
    
    var body: some View {
        VStack (spacing: 30){
            Image(img)
                .resizable()
                .aspectRatio(contentMode: .fit)
            Text(" 你是什么垃圾?").bold().italic().font(.largeTitle)
                .foregroundColor(.cyan)
            Divider()
            TextField("请输入要识别的垃圾名称", text: $input)
            Divider()
            
            if a == 0{
                Text("可回收物").foregroundColor(.green)
            }else if a == 1{
                Text("厨余垃圾").foregroundColor(.yellow)
            }else if a == 2{
                Text("有害垃圾").foregroundColor(.red)
            }else if a == 3{
                Text("其他垃圾").foregroundColor(.gray)
            }else {
            }
            
            HStack{
                Button("开始检测   "){
                    let Output = try? model.prediction(text: input)
                    let result = Output!.label
                    if input != ""{
                        if result == "可回收物" {
                            img = "垃圾箱绿"
                            a = 0
                        }else if result == "厨余垃圾"{
                            img = "垃圾箱黄"
                            a = 1
                        }else if result == "有害垃圾"{
                            img = "垃圾箱红"
                            a = 2
                        }else if result == "其他垃圾"{
                            img = "垃圾箱灰"
                            a = 3
                        }
                    }
                }.buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(.cyan)
                Button("清除搜索   "){
                    a = -1
                    input = ""
                    img = "垃圾箱蓝"
                }.buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(.teal)
                    
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .font(.title)
        .animation(.easeInOut)
    }
    
}

struct TextView_Previews: PreviewProvider {
    static var previews: some View {
        TextView()
    }
}
